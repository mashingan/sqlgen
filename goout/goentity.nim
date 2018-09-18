#? stdtmpl(emit="f.write") | standard
#
#import ../types
#import ../utils
#import gotable
#
#proc writeGoEntity*(f: File, sqltable: openarray[SqlTable], needtime = false) =
package entity

import (
#if needtime:
        "time"
#end if
)

#for tbl in sqltable:
$tbl.generateGoTable
#end for
