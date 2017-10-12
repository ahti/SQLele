import XCTest
@testable import SQLele

struct TestError: Error {}

class SQLeleTests: XCTestCase {
    var db: Connection! = nil

    override func setUp() {
        super.setUp()

        db = try! Connection()
        try! db.run("create table Test (a, b, c)")
    }

    func testBasicUsage() throws {
        let s = try db.prepare("insert into Test values (?, ?, ?)")
        try s.bind(1, to: 1 as Int64?)
        try s.bind(2, to: "foo")
        try s.bind(3, to: 123.456)
        _ = try s.step()

        let select = try db.prepare("select * from Test")
        let row = try select.step()!
        XCTAssertEqual(try row.column(0) as Int64?, 1)
        XCTAssertEqual(try row.column(1) as String?, "foo")
        XCTAssertEqual(try row.column(2) as Double?, 123.456)
    }

    func testTransaction() throws {
        try db.transaction {
            try db.run("insert into Test values (1, 2, 3)")
        }
        let count = try db.prepare("select count(*) from Test")
        let row = try count.step()!
        XCTAssertEqual(try row.column(0) as Int64?, 1)
    }

    func testTransactionRollsBackOnThrow() throws {
        do {
            try db.transaction {
                try db.run("insert into Test values (1, 2, 3)")
                throw TestError()
            }
        } catch {}
        let count = try db.prepare("select count(*) from Test")
        let row = try count.step()!
        XCTAssertEqual(try row.column(0) as Int64?, 0)
    }

    func testTransactionRollsBackOnCommitError() throws {
        try db.run("pragma foreign_keys = on")

        try db.run("create table a(id primary key, x not null)")
        try db.run("create table b(id primary key, a REFERENCES a(id) DEFERRABLE INITIALLY DEFERRED not null)")

        try db.run("insert into a values (1, 42)")
        try db.run("insert into b values (1, 1)")

        var reached = false
        do {
            try db.transaction {
                try db.run("delete from a")
                reached = true
            }
            XCTFail("transaction didn't throw")
        } catch {}
        XCTAssertTrue(reached)
        let count = try db.prepare("select count(*) from a")
        let row = try count.step()!
        XCTAssertEqual(try row.column(0) as Int64?, 1)
    }

    static var allTests = [
        ("testBasicUsage", testBasicUsage),
        ("testTransactionRollsBackOnThrow", testTransactionRollsBackOnThrow),
        ("testTransactionRollsBackOnCommitError", testTransactionRollsBackOnCommitError),
    ]
}
