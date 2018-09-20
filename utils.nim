import strutils, strformat, tables, sequtils

when not defined(release):
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
    if fpIndex in field.options: ";index" else: "",
    if fpNotNull in field.options: ";not null" else: "",
    if fpUnique in field.options and fpIndex in field.options:
      ";unique_index"
    else: ""
  ]
  "$# $# `$#`," % [field.name.toPascalCase, field.kind.toLowerAscii.typeMap,
    gormbuilder]

proc tableRelation(field: SqlField, tbls: seq[SqlTable]): FieldRelation =
  result = rOneToMany
  for tbl in tbls:
    if field.foreign.schema == tbl.schema and field.foreign.table == tbl.name:
      var fk = tbl.fields[field.foreign.field]
      if fpPrimaryKey notin fk.options or fpUnique notin fk.options:
        result = rOneToOne
        break

proc generateFieldFK*(field: SqlField, tbls: seq[SqlTable]): string =
  var rel = field.tableRelation(tbls)
  var manyid = if rel == rOneToOne: ""
               else: "[]"
  var gormbuilder = """gorm:"foreignkey:$1;association_foreignkey:$2""""
  if rel == rOneToOne:
    gormbuilder = gormbuilder % [field.name.toPascalCase,
      field.foreign.field.toPascalCase]
  else:
    gormbuilder = gormbuilder % [field.foreign.field.toPascalCase,
      field.name.toPascalCase]
  "$# $# `$#`," % [field.name.toPascalCase & "FK",
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
