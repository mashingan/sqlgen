#? stdtmpl(emit="f.write") | standard
#
#import ../types
#import ../utils
#import gotable
#
#proc writeGoEntity*(f: File, sqltable: seq[SqlTable], needtime = false) =
package entity

import (
#if needtime:
        "time"
#end if
)

#for tbl in sqltable:
#var tblstr = tbl.generateGoTable sqltable
$tblstr
#end for
