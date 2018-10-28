import sqlgen, unittest, sequtils, tables, strutils

var fname = "tests/dummyscript.sql"
var table = fname.parseSql.parse.getTables


suite "testing a basic test with dummyscript.sql file":
  var
    tbl: SqlTable
    field: SqlField
    phoneTable: SqlTable
  for t in table:
    if t.name == "users":
      tbl = t
    elif t.name == "phones":
      phoneTable = t
  test "Got 3 tables from definition":
    require(table.len == 3)

  test "There's 'users' table":
    check("users" in table.mapIt it.name)

  test "There's field 'address' in table 'users'":
    check("address" in tbl.fields)
    field = tbl.fields["address"]

  test "'users.address' is indexed":
    check(fpIndex in field.options)

  test "'phones.name' is not unique":
    check(fpUnique notin phoneTable.fields["name"].options)

  test "'phones.name' is foreign-key":
    check(fpForeignKey in phoneTable.fields["name"].options)

  test "'phones.name' references of 'users.username'":
    let phonefk = phoneTable.fields["name"].foreign
    check([phonefk.table, phonefk.field].join(".") == "users.username")

  test "'users.username' is referred by 'phones.name'":
    let usersfk = tbl.referers["phones"]
    check([usersfk.table, usersfk.field].join(".") == "phones.name")

  test "Throw 'KeyError' when accessing field 'random' in 'users'":
    expect KeyError:
      discard tbl.fields["random"]
