import sqlgen

var fname = "tests/character_varying.sql"
var table = fname.parseSql.parse.getTables

for tbl in table:
  echo tbl
stdout.writeGoEntity(table, needtime = table.needtime, version = version)
