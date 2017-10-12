import XCTest
@testable import SQLele

class SQLeleTests: XCTestCase {
    var db: Connection! = nil

    override func setUp() {
        super.setUp()

        db = try! Connection()
    }

    func testBasicUsage() throws {
        try db.run("create table Test (a, b, c)")
        let s = try db.prepare("insert into Test values (?, ?, ?)")
        try s.bind(1, to: 1 as Int64?)
        try s.bind(2, to: "foo")
        try s.bind(3, to: 123.456)
        _ = try s.step()

        let count = try db.prepare("select * from Test")
        let row = try count.step()!
        XCTAssertEqual(try row.column(0) as Int64?, 1)
        XCTAssertEqual(try row.column(1) as String?, "foo")
        XCTAssertEqual(try row.column(2) as Double?, 123.456)
    }


    static var allTests = [
        ("testBasicUsage", testBasicUsage),
    ]
}
