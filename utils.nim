import strutils, strformat, tables, sequtils

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

proc generateTableField*(field: SqlField): string =
  #fmt"{field.name.toPascalCase} {field.kind.sqlTypeMap},"
  "$# $#," % [field.name.toPascalCase, field.kind.typeMap]

proc needTime*(tbl: SqlTable): bool =
  tbl.fields.anyIt( it.kind.startsWith "time" )

proc needTime*(tbls: seq[SqlTable]): bool =
  tbls.any needTime

proc typeMap*(kind: string, sql = PostgreSql): string =
  result = "kind"
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
