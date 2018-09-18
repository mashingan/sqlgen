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
    fields*: seq[SqlField]

  Validater* = proc(x: int, tkn: seq[string]): bool

  SqlDb* = enum
    MySql PostgreSql Sqlite MariaDb

  SqlExpressions* = seq[string]
