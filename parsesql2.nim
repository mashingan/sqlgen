import os, strutils, future, sequtils

type
  FieldProps* = enum
    fpNotNull fpPrimaryKey fpUnique

  SqlField* = object
    name*: string
    kind*: string
    options*: seq[FieldProps]
    default*: string

  SqlTable* = object
    schema*, name*: string
    fields: seq[SqlField]

  Validater = proc(x: int, tkn: seq[string]): bool

proc validateTest(idx: int, tokens: seq[string], test: Validater): bool =
  result = false
  if idx != 0 and tokens.len > 1:
    result = test(idx, tokens)

proc isForeignKey(idx: int, tokens: seq[string]): bool =
  validateTest(idx, tokens, proc(x: int, tkn: seq[string]): bool =
    tkn[x] == "key" and tkn[x-1] == "foreign")

proc notValidTableName(idx: int, tokens: seq[string]): bool =
  validateTest(idx, tokens, proc(x: int, tkn: seq[string]): bool =
    (tkn[x-1]).endsWith ")")

proc purgeComments(exprstr: string): string =
  var buffer = newstring exprstr.len
  var iscomment = false
  for idx, c in exprstr:
    if c in NewLines:
      iscomment = false
    elif c == '-' and idx < exprstr.len - 1 and exprstr[idx+1] == '-':
      iscomment = true

    if not iscomment: buffer &= c
    else: stdout.write c
  buffer

proc parseOptions(expr: string): seq[FieldProps] =
  result = @[]
  if expr.len == 0:
    return

  var tokens = expr.splitWhitespace
  for idx, token in tokens:
    case token
    of "key": result.add fpPrimaryKey
    of "null": result.add fpNotNull
    of "unique": result.add fpUnique

proc tokenizeParenthesis(expr: string): string =
  var buffer = newstring(expr.len)
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
  var tokens = expr.tokenizeParenthesis.splitWhitespace
  for idx, token in tokens:
    if token == "default" and idx != tokens.len - 1:
      return tokens[idx+1]

proc parseTableField(expr: string): SqlField =
  var tokens = expr.splitWhitespace 2
  result.name = tokens[0]
  result.kind = tokens[1]
  if tokens.len > 2:
    result.options = (tokens[2]).parseOptions
    result.default = if "default" in tokens[2]: (tokens[2]).getDefault
                     else: nil

proc parseSqlTable(expr: string): SqlTable =
  var tokens = expr.purgeComments.splitWhitespace
  echo()

  var pos = -1
  for idx, token in tokens:
    if ((token == "(" or token.startsWith "(") and idx != 0) or token.endsWith "(":
      pos = idx
      #dump tokens[idx-1]
      if isForeignKey(idx-1, tokens) or notValidTableName(idx-1, tokens):
        continue
      else:
        #dump tokens[idx]
        var schemaname = newseq[string]()
        if token.endsWith("(") and token != "(":
          schemaname = (token.split('(', 1)[0]).split('.', 1)
        else:
          schemaname = (tokens[idx-1]).split('.', maxsplit=1)
        #dump schemaname
        if schemaname.len > 1:
          result.schema = schemaname[0]
          result.name = schemaname[1]
        else:
          result.schema = ""
          result.name = schemaname[0]
        break

  result.fields = @[]
  tokens = (tokens[pos+1 .. ^1]).join(sep=" ").split(',')
  for idx, token in tokens:
    if token.strip.startsWith "foreign key":
      dump token
      continue
    result.fields.add token.strip.parseTableField


proc parseExpression(exprstr: string): seq[string] =
  exprstr.split(';').mapIt it.strip

proc main =
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
        else:
          buff &= (line[0..pos] & "\n")
          tables.add buff.parseSqlTable()
          buff = line[pos+1..^1]
    else:
      discard
  for table in tables:
    echo table
    #discard

main()
