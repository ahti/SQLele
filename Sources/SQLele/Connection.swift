import SQLite3

public final class Connection {
    let handle: OpaquePointer

    private let handleIsExternal: Bool

    public init(handle: OpaquePointer) {
        self.handle = handle
        handleIsExternal = true
    }

    public init(path: String) throws {
        var handle: OpaquePointer?
        let ret = sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX, nil)

        guard let nonNilHandle = handle else {
            throw SQLeleError.outOfMemory
        }

        self.handle = nonNilHandle
        handleIsExternal = false
        do {
            try self.check(ret)
        } catch {
            sqlite3_close_v2(self.handle)
            throw error
        }
    }

    public convenience init() throws {
        try self.init(path: ":memory:")
    }

    deinit {
        if !handleIsExternal {
            sqlite3_close_v2(handle)
        }
    }

    @discardableResult func check(_ resultCode: Int32, statement: String? = nil) throws -> Int32 {
        guard let error = SQLeleError(errorCode: resultCode, connection: self, statement: statement) else {
            return resultCode
        }

        throw error
    }

    public func prepare(_ string: String) throws -> Statement {
        return try Statement(db: self, sql: string)
    }

    public func run(_ sql: String) throws {
        try _ = prepare(sql).step()
    }

    public enum TransactionMode : String {
        /// Defers locking the database until the first read/write executes.
        case deferred = "DEFERRED"

        /// Immediately acquires a reserved lock on the database.
        case immediate = "IMMEDIATE"

        /// Immediately acquires an exclusive lock on all databases.
        case exclusive = "EXCLUSIVE"
    }

    public func transaction<T>(mode: TransactionMode = .deferred, _ block: () throws -> T) throws -> T {
        try self.run("BEGIN \(mode.rawValue) TRANSACTION")
        let ret: T
        do {
            ret = try block()
            try self.run("COMMIT TRANSACTION")
        } catch {
            try self.run("ROLLBACK TRANSACTION")
            throw error
        }
        return ret
    }
}
