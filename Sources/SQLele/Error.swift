import SQLite3

public enum SQLeleError: Error {
    fileprivate static let successCodes: Set = [SQLITE_OK, SQLITE_ROW, SQLITE_DONE]

    case error(message: String, code: Int32, statement: String?)
    case noSqlInStatement(statement: String)
    case bindParameterNotFound(name: String)
    case columnNotFound(name: String)
    case typeMismatch(got: Row.StorageClass)
    case outOfMemory

    init?(errorCode: Int32, connection: Connection, statement: String? = nil) {
        guard !SQLeleError.successCodes.contains(errorCode) else { return nil }
        guard errorCode != SQLITE_MISUSE else { fatalError("SQLITE_MISUSE") }

        let message = String(cString: sqlite3_errmsg(connection.handle))
        self = .error(message: message, code: errorCode, statement: statement)
    }

}
