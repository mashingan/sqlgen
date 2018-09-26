# Package

version       = "0.1.0"
author        = "Rahmatullah"
description   = "SQL parser to create table object equivalent and Go output"
license       = "MIT"
bin           = @["sqlgen"]
srcDir        = "src"
skipDirs      = @["tests"]

# Dependencies

requires "nim >= 0.18.0"

import distros

task release, "Compiling a release version":
  var exe = ""
  if detectOs(Windows):
    exe = ".exe"
  exec("nim c -d:release -o:sqlgen" & exe & " src/sqlgen.nim")

task test, "Test dummy script sql":
  exec "nim c -r tests/test1"
