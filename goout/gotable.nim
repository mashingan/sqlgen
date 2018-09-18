#? stdtmpl | standard
#import strutils
#
#import ../types
#import ../utils
#
#proc generateGoTable*(sqltable: SqlTable): string =
#  result = ""
#var tablename = sqltable.name.toPascalCase.strip

type $tablename struct {
  #for field in sqltable.fields:
        $field.generateTableField
  #end for
}

function ($tablename) Schema() string {
        return "$sqltable.schema"
}

function ($tablename) TableName() string {
        return "$sqltable.name"
}
