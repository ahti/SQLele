import XCTest
@testable import SQLele

struct TestError: Error {}

class SQLeleTests: XCTestCase {
    var db: Connection! = nil

    override func setUp() {
        super.setUp()

        db = try! Connection()
        try! db.run("create table Test (a, b, c, d, e)")
    }

    func testBasicUsage() throws {
        let s = try db.prepare("insert into Test values (?, ?, ?, ?, ?)")
        try s.bind(1 as Int64, to: 1)
        try s.bind("foo", to: 2)
        try s.bind(123.456, to: 3)
        try s.bind(Data(bytes: [0, 1, 2, 4, 8, 16]), to: 4)

        try s.bind("overwrite me", to: 5)
        try s.bindNull(5)
        _ = try s.step()

        let select = try db.prepare("select * from Test")
        let row = try select.step()!

        XCTAssertEqual(try row.column(0) as Int64?, 1)
        XCTAssertEqual(try row.column(0) as Double?, 1)
        XCTAssertThrowsError(try row.column(0) as String?)
        XCTAssertThrowsError(try row.column(0) as Data?)

        XCTAssertThrowsError(try row.column(1) as Int64?)
        XCTAssertThrowsError(try row.column(1) as Double?)
        XCTAssertEqual(try row.column(1) as String?, "foo")
        XCTAssertThrowsError(try row.column(1) as Data?)

        XCTAssertThrowsError(try row.column(2) as Int64?)
        XCTAssertEqual(try row.column(2) as Double?, 123.456)
        XCTAssertThrowsError(try row.column(2) as String?)
        XCTAssertThrowsError(try row.column(2) as Data?)

        XCTAssertThrowsError(try row.column(3) as Int64?)
        XCTAssertThrowsError(try row.column(3) as Double?)
        XCTAssertThrowsError(try row.column(3) as String?)
        XCTAssertEqual(try row.column(3) as Data?, Data(bytes: [0, 1, 2, 4, 8, 16]))

        XCTAssertEqual(try row.column(4) as Int64?, nil)
        XCTAssertEqual(try row.column(4) as Double?, nil)
        XCTAssertEqual(try row.column(4) as String?, nil)
        XCTAssertEqual(try row.column(4) as Data?, nil)
    }

    func testTransaction() throws {
        try db.transaction {
            try db.run("insert into Test values (1, 2, 3, 4, 5)")
        }
        let count = try db.prepare("select count(*) from Test")
        let row = try count.step()!
        XCTAssertEqual(try row.column(0) as Int64?, 1)
    }

    func testTransactionRollsBackOnThrow() throws {
        do {
            try db.transaction {
                try db.run("insert into Test values (1, 2, 3, 4, 5)")
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

    func testSavepointRollbacksOnError() throws {
        do {
            try db.savepoint {
                try db.run("insert into Test values (1, 2, 3, 4, 5)")
                throw TestError()
            }
        } catch {}
        let count = try db.prepare("select count(*) from Test")
        let row = try count.step()!
        XCTAssertEqual(try row.column(0) as Int64?, 0)
    }

    func testSavepointReleasesOnError() throws {
        do {
            try db.savepoint {
                try db.run("insert into Test values (1, 2, 3, 4, 5)")
                throw TestError()
            }
        } catch {}
        // open and close a transaction, which won't work when the savepoint
        // is not released (<=> transaction stack is non-empty)
        XCTAssertNoThrow(try db.transaction {})
    }

    static var allTests = [
        ("testBasicUsage", testBasicUsage),
        ("testTransaction", testTransaction),
        ("testTransactionRollsBackOnThrow", testTransactionRollsBackOnThrow),
        ("testTransactionRollsBackOnCommitError", testTransactionRollsBackOnCommitError),
        ("testSavepointRollbacksOnError", testSavepointRollbacksOnError),
        ("testSavepointReleasesOnError", testSavepointReleasesOnError),
    ]
}
