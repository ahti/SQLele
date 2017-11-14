import SQLite3

public enum SQLeleError: Error {
    static let successCodes: Set = [SQLITE_OK, SQLITE_ROW, SQLITE_DONE]

    case error(message: String, code: Int32, statement: String?)
    case noSqlInStatement(statement: String)
    case bindParameterNotFound(name: String)
    case columnNotFound(name: String)
    case typeMismatch(got: Row.StorageClass)
    case outOfMemory
}

extension Connection {
    @discardableResult func check(_ resultCode: Int32, statement: String? = nil) throws -> Int32 {
        guard !SQLeleError.successCodes.contains(resultCode) else { return resultCode }

        let message = String(cString: sqlite3_errmsg(handle))
        guard resultCode != SQLITE_MISUSE else { fatalError("SQLITE_MISUSE: \(message)") }

        throw SQLeleError.error(message: message, code: resultCode, statement: statement)
    }
}
