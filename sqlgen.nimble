# Package

version       = "0.1.0"
author        = "Rahmatullah"
description   = "SQL parser to create table object equivalent and Go output"
license       = "MIT"
bin           = @["sqlgen"]
installExt    = @["nim"]
srcDir        = "src"
skipDirs      = @["tests"]

# Dependencies

requires "nim >= 0.18.0"

import distros, strutils

task release, "Compiling a release version":
  var exe = ""
  if detectOs(Windows):
    exe = ".exe"
  exec("nim c -d:release -o:sqlgen" & exe & " src/sqlgen.nim")

task release_tcc, "Compiling a release version using tiny-c compiler and empahsizing size":
  var exe = ""
  if detectOs Windows:
    exe = ".exe"
  let fname = "sqlgen" & exe
  exec("nim c --cc:tcc -d:release -o:$# src/sqlgen.nim" % [fname])

task basic, "Test 1 dummy script sql":
  exec "nim c -r tests/test1"

task constrained, "Test 2 constrained script sql":
  exec "nim c -r tests/test2"

task timezone, "Test 3 time zoned script sql":
  exec "nim c -r tests/test3"

task char_varying, "Test 4 character varying script sql":
  exec "nim c -r tests/test4"

task standalone_primarykey, "Test 5 constraint standalone primary key":
  exec "nim c -r tests/test5"

task standalone_uniquekey, "Test 6 constraint unique key":
  exec "nim c -r tests/test6"


task test_all, "Test all cases":
  exec "nimble basic"
  exec "nimble constrained"
  exec "nimble timezone"
  exec "nimble char_varying"
  exec "nimble standalone_primarykey"
  exec "nimble standalone_uniquekey"
