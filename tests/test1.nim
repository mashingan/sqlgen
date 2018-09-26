import sqlgen

var fname = "tests/dummyscript.sql"
var table = fname.parseSql.parse.getTables

for tbl in table:
  echo tbl
stdout.writeGoEntity(table, needtime = table.needtime, version = version)
