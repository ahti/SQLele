import SQLite3
import Foundation

public final class Statement {
    let handle: OpaquePointer
    let db: Connection
    init(db: Connection, sql: String) throws {
        self.db = db
        var handle: OpaquePointer?
        try db.check(sqlite3_prepare_v2(db.handle, sql, -1, &handle, nil))
        guard let nonNilHandle = handle else {
            throw SQLeleError.noSqlInStatement(statement: sql)
        }
        self.handle = nonNilHandle
    }

    deinit {
        sqlite3_finalize(handle)
    }
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.handle))

    public lazy var columnNames: [String] = (0..<Int32(self.columnCount)).map {
        String(cString: sqlite3_column_name(self.handle, $0))
    }

    public lazy var bindParameterCount: Int = Int(sqlite3_bind_parameter_count(self.handle))

    public func reset(clearBindings shouldClear: Bool = true) {
        // ignore return status, it only mirrors the return value of previous call to step
        _ = sqlite3_reset(handle)
        if (shouldClear) { try! db.check(sqlite3_clear_bindings(handle)) }
    }
    public func step() throws -> Bool { return try db.check(sqlite3_step(handle)) == SQLITE_ROW }

    subscript(index: Int) -> SQLValue? {
        get {
            let idx = Int32(index)
            switch sqlite3_column_type(handle, idx) {
            case SQLITE_BLOB:
                guard let pointer = sqlite3_column_blob(handle, idx) else {
                    return Data()
                }
                let length = Int(sqlite3_column_bytes(handle, idx))
                return Data(bytes: pointer, count: length)
            case SQLITE_FLOAT:
                return sqlite3_column_double(handle, idx)
            case SQLITE_INTEGER:
                return sqlite3_column_int64(handle, idx)
            case SQLITE_NULL:
                return nil
            case SQLITE_TEXT:
                return String(cString: UnsafePointer(sqlite3_column_text(handle, idx)))
            case let type:
                fatalError("unsupported column type: \(type)")
            }
        }
        set {
            let value = newValue
            let idx = Int32(index + 1)
            let ret: Int32 = {
                if value == nil {
                    return sqlite3_bind_null(handle, idx)
                } else if let value = value as? Data {
                    return value.withUnsafeBytes({
                        sqlite3_bind_blob(handle, idx, $0, Int32(value.count), SQLITE_TRANSIENT)
                    })
                } else if let value = value as? Double {
                    return sqlite3_bind_double(handle, idx, value)
                } else if let value = value as? Int64 {
                    return sqlite3_bind_int64(handle, idx, value)
                } else if let value = value as? String {
                    return sqlite3_bind_text(handle, idx, value, -1, SQLITE_TRANSIENT)
                } else {
                    fatalError("tried to bind unexpected value \(String(describing: value))")
                }
            }()

            try! db.check(ret)
        }
    }

    func get<T>(index: Int) throws -> T? where T: SQLConvertible {
        return try self[index].map(T.fromSQLValue)
    }

    func get<T>(index: Int) throws -> T where T: SQLConvertible {
        guard let v = try get(index: index) as T? else {
            throw SQLConversionError.unexpectedNull
        }
        return v
    }

    lazy var columnNameMap: [String: Int] = self.columnNames.enumerated().reduce([String: Int](), {
        var d = $0
        d[$1.element] = $1.offset
        return d
    })

    private func columnFor(name column: String) throws -> Int {
        guard let idx = columnNameMap[column] else {
            throw SQLConversionError.unknownColumn(name: column)
        }
        return idx
    }

    public func get(column: String) throws -> SQLValue {
        guard let v = self[try columnFor(name: column)] else {
            throw SQLConversionError.unexpectedNull
        }
        return v
    }

    public func get(column: String) throws -> SQLValue? {
        return self[try columnFor(name: column)]
    }

    public func get<T>(column: String) throws -> T? where T: SQLConvertible {
        return try get(index: try columnFor(name: column)) as T?
    }

    public func get<T>(column: String) throws -> T where T: SQLConvertible {
        return try get(index: try columnFor(name: column)) as T
    }

    @discardableResult public func bind(values: [SQLValue?]) -> Statement {
        guard values.count == bindParameterCount else {
            fatalError("bound values count (\(values.count)) unequal to bindParameterCount (\(bindParameterCount))")
        }
        reset()

        for (index, value) in values.enumerated() {
            self[index] = value
        }

        return self
    }

    @discardableResult public func bind(values: [SQLConvertible?]) -> Statement {
        return bind(values: values.map { $0?.sqlValue })
    }
}
