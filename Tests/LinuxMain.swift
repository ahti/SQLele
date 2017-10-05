#if os(Linux)
import XCTest
@testable import SQLeleTests

XCTMain([
    testCase(SQLeleTests.allTests),
])
#endif
