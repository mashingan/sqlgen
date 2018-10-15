import os, strutils, sequtils, tables

when not defined(release):
  when NimMinor >= 19:
    import sugar
  else:
    import future

import types, utils
import goout/gotable
import goout/goentity

proc validateTest(idx: int, tokens: seq[string], test: Validater): bool =
  result = false
  if idx != 0 and tokens.len > 1:
    result = test(idx, tokens)

proc isForeignKey(idx: int, tokens: seq[string]): bool =
  validateTest(idx, tokens, proc(x: int, tkn: seq[string]): bool =
    tkn[x] == "key" and tkn[x-1] == "foreign")

proc notValidTableName(idx: int, tokens: seq[string]): bool =
  validateTest(idx, tokens, proc(x: int, tkn: seq[string]): bool =
    tkn[x-1].endsWith ")")

proc purgeComments(exprstr: string): string =
  var buffer = ""
  var iscomment = false
  for idx, c in exprstr:
    if c in NewLines:
      iscomment = false
    elif c == '-' and idx < exprstr.len - 1 and exprstr[idx+1] == '-':
      iscomment = true

    if not iscomment: buffer &= c
    #else: stdout.write c
  buffer

proc parseOptions(expr: string): set[FieldProps] =
  result = {}
  if expr.len == 0:
    return

  var tokens = expr.splitWhitespace
  for idx, token in tokens:
    case token
    of "key": result.incl fpPrimaryKey
    of "null": result.incl fpNotNull
    of "unique": result.incl fpUnique
    of "index": result.incl fpIndex
    of "references": result.incl fpForeignKey

proc tokenizeParenthesis(expr: string): string =
  var buffer = ""
  var isparenthesis = false
  for c in expr:
    case c
    of '(': isparenthesis = true
    of ')': isparenthesis = false
    else: discard

    if c in Whitespace and isparenthesis:
      continue
    buffer &= c
  buffer

proc getDefault(expr: string): string =
  var tokens = expr.splitWhitespace
  for idx, token in tokens:
    if token == "default" and idx != tokens.len - 1:
      return tokens[idx+1]

proc splitSchemaName(schnm: string): (string, string) =
  var schname = schnm.split('.', 1)
  if schname.len >= 2:
    (schname[0], schname[1])
  else:
    ("", schname[0])

proc parseForeign(expr: string): SqlForeign =
  template stripP(thevar: untyped): untyped =
    thevar.strip(chars={'(', ')'})

  var tokens = expr.splitWhitespace
  var pos = -1
  for idx, token in tokens:
    pos = idx
    if token == "references": break
  if pos == tokens.len - 1:
    return SqlForeign()
  for idx, token in tokens[pos+1 .. ^1]:
    var parpos = token.find '('
    if parpos == -1:
      (result.schema, result.table) = tokens[pos+1+idx].splitSchemaName
      if idx+pos < tokens.len - 1 and tokens[pos+1+idx+1].startsWith("("):
        result.field = tokens[pos+1+idx+1].stripP
      break
    elif parpos == 0 and idx != 0:
      (result.schema, result.table) = tokens[pos+1+idx-1].splitSchemaName
      if idx+pos != tokens.len - 1 and token != "(":
        result.field = tokens[pos+idx].strip(chars = {'(', ')'} + Whitespace)
        break

    elif parpos != token.len - 1:
      var schname_fld = tokens[pos+1+idx].split('(', 1)
      (result.schema, result.table) = schname_fld[0].splitSchemaName
      result.field = schname_fld[1].split(')')[0]
      break

    elif parpos == token.len - 1:
      var schname_fld = tokens[idx].split('(', 1)
      (result.schema, result.table) = schname_fld[0].splitSchemaName
      if schname_fld[1].endsWith ")":
        var fld = schname_fld[1].split(')')
        result.field = fld[0]
        break
  result.relatedField = ""

proc contains*(str, sub: string): bool =
  if str.find(sub) != -1: true
  else: false

proc isForeignConstraint(expr: string): bool =
  result = false
  if (expr.startsWith("constraint") and "foreign" in expr) or
      expr.startsWith("foreign"):
    result = true

proc discardConstraintToken(expr: string): seq[string] =
  var tokens = expr.splitWhitespace
  var foundForeign = false
  for token in tokens:
    if token == "foreign" or token.startsWith "foreign":
      foundForeign = true

    if not foundForeign: continue

    result.add token


proc hasWithTimezone(expr: string): bool =
  ["with", "time", "zone"].allIt( it in expr )

proc isPrimaryKeyConstraint(expr: string): bool =
  (expr.startsWith("constraint") and "primary" in expr) or
    expr.startsWith "primary"

proc isUniqueConstraint(expr: string): bool =
  (expr.startsWith("constraint") and "unique" in expr) or
    expr.startsWith "unique"

template stripParen(str: string): untyped =
  str.strip(chars = {'(', ')'})

proc parseTableField(tbl: var SqlTable, expr: string, sqltype: SqlDb): SqlField =
  var tokens = expr.splitWhitespace 2
  when not defined(release):
    dump expr
    dump tokens
  if expr.isForeignConstraint:
    tokens = expr.discardConstraintToken
    var fieldname = tokens[2].split(')', 1)[0].strip(chars = {'(', ')'})
    when not defined(release): dump fieldname
    var field = tbl.fields[fieldname]
    field.options.incl fpForeignKey
    field.foreign = expr.parseForeign
    field.foreign.isUnique = fpUnique in field.options
    return field
  elif expr.isPrimaryKeyConstraint:
    var fieldname = expr[expr.find("(") + 1 .. expr.find(")")-1]
    var field = tbl.fields[fieldname]
    field.options.incl fpPrimaryKey
    return field
  elif expr.isUniqueConstraint:
    var fieldname = expr[expr.find("(")+1 .. expr.find(")")-1]
    var field = tbl.fields[fieldname]
    field.options.incl fpUnique
    return field
  result.name = tokens[0].strip(chars = {'`', '"'})
  if tokens[1] == "character" and tokens[2].startsWith "varying":
    result.kind = "varchar"
    var oldline = tokens[2]
    tokens[2] = oldline[oldline.find(")")+1 .. ^1]
  else:
    result.kind = tokens[1]
  result.dbType = sqltype
  if tokens.len > 2:
    var infofield = tokens[2]
    if result.kind.startsWith("time") and infofield.hasWithTimezone:
      # WARNING: ERROR when the syntax is not correct
      if "without" notin infofield: result.kind &= "tz"
      infofield = infofield.splitWhitespace[3 .. ^1].join " "
    result.options = infofield.parseOptions
    result.default = if "default" in infofield: infofield.getDefault
                     else: ""
    result.foreign = infofield.parseForeign
    result.foreign.isUnique = fpUnique in result.options
  else:
    result.options = {}
    result.default = ""
  when not defined(release):
    dump result

proc parseSqlTable*(expr: string, sqltype = PostgreSql): SqlTable =
  var tokens = expr.purgeComments.splitWhitespace

  var pos = -1
  for idx, token in tokens:
    if ((token == "(" or token.startsWith "(") and idx != 0) or token.endsWith "(":
      pos = idx
      if isForeignKey(idx-1, tokens) or notValidTableName(idx-1, tokens):
        continue
      else:
        var schemaname = newseq[string]()
        if token.endsWith("(") and token != "(":
          schemaname = (token.split('(', 1)[0]).split('.', 1)
        else:
          schemaname = tokens[idx-1].split('.', maxsplit=1)
        if schemaname.len > 1:
          result.schema = schemaname[0]
          result.name = schemaname[1]
        else:
          result.schema = ""
          result.name = schemaname[0]
        break

  result.fields = newTable[string, SqlField]()
  result.referers = newTable[string, SqlForeign]()
  tokens = (tokens[pos+1 .. ^1]).join(sep=" ").split(',')
  for idx, token in tokens:
    var field = result.parseTableField(token.strip.tokenizeParenthesis, sqltype)
    result.fields[field.name] = field


proc parseExpression*(exprstr: string): seq[string] =
  exprstr.split(';').mapIt it.strip

proc parse*(lines: seq[string]): seq[string] =
  result = @[]
  var
    prevline = ""
    cont = false
    ln = ""
  for line in lines:
    if line.startsWith("\\") or line.startsWith("--"):
      continue

    if cont: ln = prevline & line
    else: ln = line

    prevline = ""
    cont = false

    var exprs = ln.split(';')
    if ln.endsWith ';':
      if exprs.len == 1: result.add ln
      elif exprs.len > 1:
        for expr in exprs:
          if expr != "": result.add(expr & ';')
    else:
      if exprs.len == 1:
        prevline = ln
      elif exprs.len > 1:
        for expr in exprs[0..^2]:
          if expr != "": result.add(expr & ';')
        prevline = exprs[^1]
      cont = true

proc parseSql*(file: File): SqlExpressions =
  var buff = newseq[string]()
  while not file.endOfFile:
    var line = file.readLine & "\n"
    if line == "": continue
    buff.add line.strip(trailing = false)
  buff.parse

proc parseSql*(filename: string): SqlExpressions =
  var file = open filename
  result = file.parseSql
  close file

proc getTables*(exprs: SqlExpressions, sqlType = PostgreSql): seq[SqlTable] =
  result = @[]
  for expr in exprs:
    var expression = expr.toLowerAscii
    var tokens = expression.splitWhitespace
    if tokens.len > 2 and tokens[0] == "create" and tokens[1] == "table":
      result.add expression.parseSqlTable
  relate result

when isMainModule:
  proc main =
    when defined(release):
      var (filename, outpath) = parseCmd()

    when not defined(release):
      var fname: string = ""
      if paramcount() >= 1:
        fname = paramStr 1
      else:
        quit "Please supply filename"

      var file = open fname
      var line = ""
      var buff = ""
      var tables = newSeq[SqlTable]()
      while file.readLine line:
        var tokens = line.toLowerAscii.splitWhitespace

        if tokens.len > 2 and tokens[0] == "create" and tokens[1] == "table":
          #echo line
          buff &= (line & "\n")
          while file.readLine line:
            line = line.toLowerAscii
            var pos = line.find(';')
            if pos == line.len - 1:
              buff &= (line & "\n")
              tables.add buff.parseSqlTable()
              buff = ""
              break
            elif pos == -1:
              buff &= (line & "\n")
            else:
              buff &= (line[0..pos] & "\n")
              tables.add buff.parseSqlTable()
              buff = line[pos+1..^1]
        else:
          discard
      #stdout.writeGoEntity(tables, needtime = tables.needtime)

      file.setFilePos 0
      var exprs = newseq[string]()
      while not file.endOfFile:
        var line = file.readLine & "\n"
        if line == "": continue
        exprs.add line.strip(trailing = false)
      close file

      var newtables = fname.parseSql.parse.getTables
      stdout.writeGoEntity(newtables, needtime = newtables.needtime)

    when defined(release):
      var tables = filename.parseSql.parse.getTables
      var outfile: File
      if outpath == "stdout" or outpath == "":
        outfile = stdout
      else:
        outfile = open(outpath, fmWrite)
      outfile.writeGoEntity(tables, needtime = tables.needtime)


  main()
