import tables

type
  FieldProps* = enum
    fpNotNull fpPrimaryKey fpUnique fpIndex fpForeignKey

  FieldRelation* = enum
    rOneToOne, rOneToMany

  SqlForeign* = object
    schema*, table*, field*, kind*: string
    relatedField*: string
    isUnique*: bool

  SqlField* = object
    name*: string
    kind*: string
    options*: set[FieldProps]
    default*: string
    foreign*: SqlForeign

  SqlTable* = object
    schema*, name*: string
    fields*: TableRef[string, SqlField]
    referers*: TableRef[string, SqlForeign]

  Validater* = proc(x: int, tkn: seq[string]): bool

  SqlDb* = enum
    MySql PostgreSql Sqlite MariaDb

  SqlExpressions* = seq[string]
