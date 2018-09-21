import tables

type
  FieldProps* = enum
    fpNotNull fpPrimaryKey fpUnique fpIndex fpForeignKey

  FieldRelation* = enum
    rOneToOne, rOneToMany

  SqlForeign* = object
    schema*, table*, field*: string

  SqlField* = object
    name*: string
    kind*: string
    options*: seq[FieldProps]
    default*: string
    foreign*: SqlForeign

  SqlTable* = object
    schema*, name*: string
    fields*: TableRef[string, SqlField]

  Validater* = proc(x: int, tkn: seq[string]): bool

  SqlDb* = enum
    MySql PostgreSql Sqlite MariaDb

  SqlExpressions* = seq[string]
