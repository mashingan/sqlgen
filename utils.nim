import strutils, strformat, tables, sequtils, parseopt, os

when not defined(release):
  import strformat
  import future

import types

template caseChange(str: string, changeFirst = false): string =
  var buffer = "0"
  when changeFirst:
    buffer[0] = str[0].toUpperAscii
    var pos = 1
  else:
    var pos = 0
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

proc typeMap*(kind: string, sql = PostgreSql): string

proc hasForeignKey*(field: SqlField): bool =
  fpForeignKey in field.options

proc hasForeignKey*(tbl: SqlTable): bool =
  for field in tbl.fields.values:
    if field.hasForeignKey:
      return true
  false

proc generateTableField*(field: SqlField): string =
  #fmt"{field.name.toPascalCase} {field.kind.sqlTypeMap},"

  #dump field
  var gormbuilder = """gorm:"column:$1;type:$2$3$4$5$6$7$8"""" % [
    field.name,
    field.kind,
    if field.default != "": ";default:" & field.default else: "",
    if fpPrimaryKey in field.options: ";primary_key" else: "",
    if fpUnique in field.options: ";unique" else: "",
    if fpIndex in field.options: ";index:" % [field.name] else: "",
    if fpNotNull in field.options: ";not null" else: "",
    if fpUnique in field.options and fpIndex in field.options:
      ";unique_index"
    else: ""
  ]
  "$# $# `$#`" % [field.name.toPascalCase, field.kind.typeMap,
    gormbuilder]

proc tableRelation(field: SqlField): FieldRelation =
  if fpUnique in field.options:
    rOneToOne
  else:
    rOneToMany

proc generateFieldFK*(field: SqlField): string =
  var rel = field.tableRelation
  var manyid = if rel == rOneToOne: ""
               else: "[]"
  var gormbuilder = """gorm:"foreignkey:$1;association_foreignkey:$2""""
  if rel == rOneToOne:
    gormbuilder = gormbuilder % [field.name.toPascalCase,
      field.foreign.field.toPascalCase]
  else:
    gormbuilder = gormbuilder % [field.foreign.field.toPascalCase,
      field.name.toPascalCase]
  "$# $# `$#`" % [field.name.toPascalCase & "FK",
    manyid & field.foreign.table.toPascalCase, gormbuilder]

proc needTime*(tbl: SqlTable): bool =
  for field in tbl.fields.values:
    if field.kind.startsWith "time":
      return true
  #tbl.fields().values().toSeq.anyIt( it.kind.startsWith "time" )
  false

proc needTime*(tbls: seq[SqlTable]): bool =
  tbls.any needTime

proc typeMap*(kind: string, sql = PostgreSql): string =
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

proc parseCmd*(): tuple[sqlfile, outpath: string] =
  var
    sqlfile = ""
    outpath = ""
    options = """
parsesql: program to get SQL script and put the output to file
Usage:
  --input | --file | -i | -f  supply the input sql script path file
  --out   | -o                provide the output path file
  --help  | -h                print this

Example:
  $./parsesql -f=/path/of/sql/script --out:entity.go

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
      of "out", "o":                outpath = val
      of "help", "h":               toQuit QuitSuccess
    of cmdEnd:
      toQuit QuitFailure

  if sqlfile == "":
    echo "please provide file"
    toQuit QuitFailure
  elif not fileExists(sqlfile):
    echo sqlfile, " not available"
    toQuit QuitFailure

  (sqlfile, outpath)
