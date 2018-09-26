#? stdtmpl | standard
#import strutils, tables
#
#import ../types
#import ../utils
#
#proc generateGoTable*(sqltable: SqlTable, tbls: seq[SqlTable]): string =
#  result = ""
#var tablename = sqltable.name.toPascalCase.strip

type $tablename struct {
  #for field in sqltable.fields.values:
        $field.generateTableField
  #end for
  #for refer in sqltable.referers.values:
        $refer.generateFieldFK
  #end for
}

func ($tablename) Schema() string {
        return "$sqltable.schema"
}

func ($tablename) TableName() string {
        return "$sqltable.name"
}
