import strutils, strformat, tables, sequtils, parseopt, os
import strformat

when not defined(release):
  when NimMinor >= 19:
    import sugar
  else:
    import future

import types

template caseChange(str: string, changeFirst = false): string =
  var buffer = "0"
  when changeFirst:
    buffer[0] = str[0].toUpperAscii
    var pos = 1
  else:
    var pos = 0
    buffer = ""
  while pos < str.len:
    var c = str[pos]
    if c == '_':
      buffer &= str[pos+1].toUpperAscii
      pos.inc 2
    else:
      buffer &= c
      inc pos
  buffer

proc toCamelCase*(str: string): string =
  str.caseChange

proc toPascalCase*(str: string): string =
  str.caseChange true

proc typeMap*(field: SqlField): string
proc typeMap*(kind: string, sql: SqlDb): string

proc hasForeignKey*(field: SqlField): bool =
  fpForeignKey in field.options

proc hasForeignKey*(tbl: SqlTable): bool =
  for field in tbl.fields.values:
    if field.hasForeignKey:
      return true
  false

converter toSqlDb(kind: string): SqlDb =
  case kind.toLowerAscii
  of "postgresql": result = PostgreSql
  of "sqlite": result = Sqlite
  of "mysql": result = MySql
  of "mariadb": result = MariaDb

proc generateTableField*(field: SqlField): string =
  #fmt"{field.name.toPascalCase} {field.kind.sqlTypeMap},"

  #dump field
  var gormbuilder = """gorm:"column:$1;type:$2$3$4$5$6$7$8"""" % [
    field.name,
    field.kind,
    if field.default != "": ";default:" & field.default else: "",
    if fpPrimaryKey in field.options: ";primary_key" else: "",
    if fpUnique in field.options: ";unique" else: "",
    if fpIndex in field.options: ";index:$#" % [field.name] else: "",
    if fpNotNull in field.options: ";not null" else: "",
    if fpUnique in field.options and fpIndex in field.options:
      ";unique_index"
    else: ""
  ]
  "$# $# `$#`" % [field.name.toPascalCase, field.typeMap,
    gormbuilder]

proc tableRelation*(field: SqlField): FieldRelation =
  if fpUnique in field.options:
    rOneToOne
  else:
    rOneToMany

proc generateFieldFK*(field: SqlField): string =
  var
    rel = field.tableRelation
    manyid = if rel == rOneToOne: "" else: "[]"
    gormbuilder = """gorm:"foreignkey:$1;association_foreignkey:$2""""
  if rel == rOneToOne:
    gormbuilder = gormbuilder % [field.name.toPascalCase,
      field.foreign.field.toPascalCase]
  else:
    gormbuilder = gormbuilder % [field.foreign.field.toPascalCase,
      field.name.toPascalCase]
  "$# $# `$#`" % [field.name.toPascalCase & "FK",
    manyid & field.foreign.table.toPascalCase, gormbuilder]

proc generateFieldFK*(refforeign: SqlForeign, sqltype = PostgreSql): string =
  var
    one2one = if refforeign.isUnique: true else: false
    manyid = if one2one: "" else: "[]"
    fieldname = refforeign.field.toPascalCase
    refererTable = refforeign.table.toPascalCase
    refRefer = refererTable & "Refer"
    refKind = refforeign.kind.typeMap sqltype
    gormbuilder = """gorm:"foreignkey:$1;association_foreignkey:$2"""
  if one2one:
    gormbuilder = gormbuilder % [refRefer, fieldname]
  else:
    gormbuilder = gormbuilder % [fieldname, refforeign.relatedField.toPascalCase]

  result = "$# $# `$#`" % [refererTable, manyid & refererTable, gormbuilder]
  if one2one:
    result &= "\n"
    result &= indent(fmt"""{refRefer} {refKind}""", 8)


proc needTime*(tbl: SqlTable): bool =
  for field in tbl.fields.values:
    if field.kind.startsWith "time":
      return true
  #tbl.fields().values().toSeq.anyIt( it.kind.startsWith "time" )
  false

proc needTime*(tbls: seq[SqlTable]): bool =
  tbls.any needTime

proc typeMap*(field: SqlField): string =
  field.kind.typeMap field.dbType

proc typeMap*(kind: string, sql: SqlDb): string =
  result = kind
  case sql
  of PostgreSql:
    case kind
    of "bigserial", "int64": result = "int64"
    of "serial", "int": result = "int"
    of "int8": result = "int8"
    of "money": result = "float64"
    of "timestamp", "timestampt", "timestamptz": result = "time.Time"
    of "text": result = "string"

    if kind.startsWith "varchar": result = "string"
  of MySql, MariaDb:
    discard
  of Sqlite:
    discard
  else:
    discard

proc parseCmd*(version = ""): tuple[sqlfile, outpath: string, sqlType: SqlDb] =
  var
    sqlfile = ""
    outpath = ""
    sqltype = ""
    options = """
parsesql: program to get SQL script and put the output to file
Usage:
  --input   | --file | -i | -f  supply the input sql script path file
  --sql                         choose the sql db type
                                  values: postgresql, mariadb, sqlite, mysql
                                  default: postgresql
  --out     | -o                provide the output path file
  --version | -v                print version
  --help    | -h                print this

Example:
  $./sqlgen -f=/path/of/sql/script --out:entity.go

Any error will during parsing option will yield QuitFailure (-1) exit code.
If there's no provided output path or `-o=stdout` then the out file will be stdout.
"""
  template toQuit(exitcode: int): typed =
    echo options
    quit exitcode

  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      when not defined(relese):
        echo fmt"{key} {val}"
        sqlfile = val
      discard
    of cmdLongOption, cmdShortOption:
      case key
      of "input", "file", "i", "f": sqlfile = val
      of "sql":                     sqltype = val
      of "out", "o":                outpath = val
      of "version", "v":
        echo "sqlgen " & version
        quit QuitSuccess
      of "help", "h":               toQuit QuitSuccess
    of cmdEnd:
      toQuit QuitFailure

  if sqlfile == "":
    echo "please provide file"
    toQuit QuitFailure
  elif not fileExists(sqlfile):
    echo sqlfile, " not available"
    toQuit QuitFailure

  if sqltype == "": sqltype = "postgresql"

  (sqlfile, outpath, sqltype.toSqlDb)

proc relate(field: SqlField, tables: var seq[SqlTable]): var SqlTable =
  for table in tables.mitems:
    if field.foreign.schema == table.schema and
       field.foreign.table == table.name:
      return table

proc joinSchemaName(schema, name: string): string =
  if schema == "": result = name
  else: result = ([schema, name]).join(".")

proc joinSchemaName*(table: SqlTable): string =
  joinSchemaName(table.schema, table.name)

proc `==`*(a, b: SqlTable): bool =
  a.schema == b.schema and a.name == b.name

proc empty(tbl: SqlTable): bool =
  tbl.schema == "" and tbl.name == "" and tbl.fields.isNil

proc relate*(sqltables: var seq[SqlTable]) =
  for sqltable in sqltables.mitems:
    for field in sqltable.fields.values:
      if fpForeignKey notin field.options: continue
      var tbl = field.relate sqltables
      if tbl == sqltable or tbl.empty: continue
      tbl.referers[sqltable.joinSchemaName] = SqlForeign(
        schema: sqltable.schema,
        table: sqltable.name,
        field: field.name,
        kind: field.kind,
        relatedField: field.foreign.field,
        isUnique: field.foreign.isUnique)

proc `$`*(table: SqlTable): string =
  result = "TABLE"
  result &= " " & table.joinSchemaName & "\n"
  result &= "fields:\n"
  var fields = ""
  for field in table.fields.values:
    fields &= "fld: " & [field.name, field.kind].join(" ") & "\n"
  result &= fields.indent(2)
  result &= "referers:\n"
  var refs = ""
  for referer in table.referers.values:
    refs &= "ref: " & [referer.schema, referer.table, referer.field].join(" ") &
      "\n"
    refs &= "is unique: " & $referer.isUnique & "\n"
    refs &= "relatedField: " & referer.relatedField & '\n'
  result &= refs.indent(2)
