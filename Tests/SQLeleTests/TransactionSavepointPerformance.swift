//
//  TransactionSavepointPerformance.swift
//  SQLeleTests
//
//  Created by Lukas Stabe on 2017-11-13.
//

import XCTest
import SQLele

class TransactionSavepointPerformance: XCTestCase {

    var db: Connection! = nil
    var path: String! = nil
    
    override func setUp() {
        super.setUp()
        path = NSTemporaryDirectory() + "/db.sqlite"
        try? FileManager.default.removeItem(atPath: path)
        db = try! Connection(path: path)
        try! db.run("create table Test (a, b, c, d)")
    }
    
    override func tearDown() {
        super.tearDown()
        db = nil
        try! FileManager.default.removeItem(atPath: path)
        path = nil
    }

    func inner() {
        let s = try! db.prepare("insert into Test values (?, ?, ?, ?)")
        for el in [(1,2,3,4), (5,6,7,8), (0,-10,42,8), (9, 99, 999, 9999)] as [(Int64, Int64, Int64, Int64)] {
            try! s.bind(1, to: el.0)
            try! s.bind(2, to: el.1)
            try! s.bind(3, to: el.2)
            try! s.bind(4, to: el.3)
            _ = try! s.step()
            s.reset()
            s.clearBindings()
        }
    }
    
    func testTransaction() {
        self.measure {
            for _ in 1...100 {
                try! db.transaction {
                    inner()
                }
            }
        }
    }

    func testSavepoint() {
        self.measure {
            for _ in 1...100 {
                try! db.savepoint {
                    inner()
                }
            }
        }
    }

    static var allTests = [
        ("testTransaction", testTransaction),
        ("testSavepoint", testSavepoint),
    ]
}
