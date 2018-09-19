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
        #if field.hasForeignKey:
        #var fkfield = field.generateFieldFK tbls
        $fkfield
        #end if
  #end for
}

function ($tablename) Schema() string {
        return "$sqltable.schema"
}

function ($tablename) TableName() string {
        return "$sqltable.name"
}
