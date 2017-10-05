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
        try _ = db.prepare("insert into Test values (?, ?, ?)").bind(values: [1, 2, 3]).step()

        let count = try db.prepare("select count(*) from Test")
        XCTAssertEqual(count.columnCount, 1)
        XCTAssertEqual(try count.step(), true)
        XCTAssertEqual(count[0] as? Int64, 1)

        let s = try db.prepare("select * from Test")
        XCTAssertEqual(s.columnCount, 3)
        XCTAssertEqual(try s.step(), true)
        XCTAssertEqual(s[2] as? Int64, 3)
    }


    static var allTests = [
        ("testBasicUsage", testBasicUsage),
    ]
}
