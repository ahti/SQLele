import SQLite3
import Foundation

public final class Row {
    let handle: OpaquePointer
    let db: Connection
    let statement: Statement
    let stepIndex: Int

    init(db: Connection, handle: OpaquePointer, statement: Statement, stepIndex: Int) {
        self.db = db
        self.handle = handle
        self.statement = statement
        self.stepIndex = stepIndex
    }

    private func guardOverstep() {
        guard statement.stepIndex == stepIndex else { fatalError("don't access Row methods after stepping the statement further") }
    }

    public enum StorageClass: Int32 {
        case integer = 1
        case real = 2
        case text = 3
        case blob = 4
        case null = 5
    }

    public func storageClass(at index: Int) -> StorageClass {
        guardOverstep()
        return StorageClass(rawValue: sqlite3_column_type(handle, Int32(index)))!
    }

    public func columnIsNull(_ index: Int) -> Bool {
        guardOverstep()
        return .null == storageClass(at: index)
    }

    public func column(_ index: Int) throws -> Int64? {
        guardOverstep()
        switch storageClass(at: index) {
        case .null: return nil
        case .integer: return sqlite3_column_int64(handle, Int32(index))
        case let other: throw SQLeleError.typeMismatch(got: other)
        }
    }

    public func column(_ index: Int) throws -> Double? {
        guardOverstep()
        switch storageClass(at: index) {
        case .null: return nil
        case .integer, .real: return sqlite3_column_double(handle, Int32(index))
        case let other: throw SQLeleError.typeMismatch(got: other)
        }
    }

    public func column(_ index: Int) throws -> String? {
        guardOverstep()
        switch storageClass(at: index) {
        case .null: return nil
        case .text: return String(cString: UnsafePointer(sqlite3_column_text(handle, Int32(index))))
        case let other: throw SQLeleError.typeMismatch(got: other)
        }
    }

    public func column(_ index: Int) throws -> Data? {
        guardOverstep()
        switch storageClass(at: index) {
        case .null: return nil
        case .blob:
            let i = Int32(index)
            guard let pointer = sqlite3_column_blob(handle, i) else {
                return Data()
            }
            let length = Int(sqlite3_column_bytes(handle, i))
            return Data(bytes: pointer, count: length)
        case let other: throw SQLeleError.typeMismatch(got: other)
        }
    }

    private func columnIndex(_ name: String) throws -> Int {
        guard let n = columnNameMap[name] else { throw SQLeleError.columnNotFound(name: name) }
        return n
    }

    public func columnIsNull(_ name: String) throws -> Bool { return try columnIsNull(columnIndex(name)) }
    public func column(_ name: String) throws -> Int64? { return try column(columnIndex(name)) }
    public func column(_ name: String) throws -> Double? { return try column(columnIndex(name)) }
    public func column(_ name: String) throws -> String? { return try column(columnIndex(name)) }
    public func column(_ name: String) throws -> Data? { return try column(columnIndex(name)) }

    public var columnCount: Int { return statement.columnCount }
    public var columnNames: [String] { return statement.columnNames }
    public var columnNameMap: [String: Int] { return statement.columnNameMap }

    private func untypedColumn(_ index: Int) throws -> Any? {
        switch storageClass(at: index) {
        case .blob: return try column(index) as Data?
        case .real: return try column(index) as Double?
        case .integer: return try column(index) as Int64?
        case .text: return try column(index) as String?
        case .null: return nil
        }
    }

    fileprivate func dictionary() throws -> [String: Any?] {
        return try columnNameMap.mapValues(untypedColumn)
    }
}

extension Row: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard let dict = try? dictionary() else { return "error" }
        return dict.debugDescription
    }
}

public final class Statement {
    let handle: OpaquePointer
    let db: Connection
    let sql: String
    init(db: Connection, sql: String) throws {
        self.db = db
        self.sql = sql
        var handle: OpaquePointer?
        try db.check(sqlite3_prepare_v2(db.handle, sql, -1, &handle, nil), statement: sql)
        guard let nonNilHandle = handle else {
            throw SQLeleError.noSqlInStatement(statement: sql)
        }
        self.handle = nonNilHandle
    }

    deinit {
        sqlite3_finalize(handle)
    }

    public func reset() {
        // ignore return status, it only mirrors the return value of previous call to step
        stepIndex += 1
        _ = sqlite3_reset(handle)
    }

    public func clearBindings() {
        // try! because the current implementation never errors
        try! db.check(sqlite3_clear_bindings(handle), statement: sql)
    }

    fileprivate var stepIndex: Int = 0
    public func step() throws -> Row? {
        stepIndex += 1
        guard try db.check(sqlite3_step(handle), statement: sql) == SQLITE_ROW else { return nil }
        return Row(db: db, handle: handle, statement: self, stepIndex: stepIndex)
    }

    // result columns are stored here so they are not recalculated, but exposed through Row
    fileprivate lazy var columnCount: Int = Int(sqlite3_column_count(self.handle))
    fileprivate lazy var columnNames: [String] = (0..<self.columnCount).map {
        String(cString: sqlite3_column_name(handle, Int32($0)))
    }
    fileprivate lazy var columnNameMap: [String: Int] = self.columnNames.enumerated().reduce(into: [String: Int](), {
        $0[$1.element] = $1.offset
    })

    public lazy var lastBindParameterIndex: Int = Int(sqlite3_bind_parameter_count(self.handle))

    public lazy var bindParameterNames: [String?] = (1...Int32(self.lastBindParameterIndex)).map {
        guard let s = sqlite3_bind_parameter_name(self.handle, $0) else { return nil }
        return String(cString: s)
    }

    public lazy var bindParameterNameMap: [String: Int] = zip(1..., self.bindParameterNames).reduce(into: [String: Int]()) { buf, el in
        guard let name = el.1 else { return }
        buf[name] = el.0
    }

    public func bindParameterIndex(_ name: String) throws -> Int {
        guard let i = bindParameterNameMap[name] else {
            throw SQLeleError.bindParameterNotFound(name: name)
        }
        return i
    }

    public func bindNull(_ index: Int) throws {
        try db.check(sqlite3_bind_null(handle, Int32(index)), statement: sql)
    }

    public func bind(_ index: Int, to value: Int64?) throws {
        guard let value = value else {
            try db.check(sqlite3_bind_null(handle, Int32(index)), statement: sql)
            return
        }
        try db.check(sqlite3_bind_int64(handle, Int32(index), value), statement: sql)
    }

    public func bind(_ index: Int, to value: Double?) throws {
        guard let value = value else {
            try db.check(sqlite3_bind_null(handle, Int32(index)), statement: sql)
            return
        }
        try db.check(sqlite3_bind_double(handle, Int32(index), value), statement: sql)
    }

    public func bind(_ index: Int, to value: String?) throws {
        guard let value = value else {
            try db.check(sqlite3_bind_null(handle, Int32(index)), statement: sql)
            return
        }
        try db.check(sqlite3_bind_text(handle, Int32(index), value, -1, SQLITE_TRANSIENT), statement: sql)
    }

    public func bind(_ index: Int, to value: Data?) throws {
        guard let value = value else {
            try db.check(sqlite3_bind_null(handle, Int32(index)), statement: sql)
            return
        }
        try db.check(value.withUnsafeBytes({
            sqlite3_bind_blob(handle, Int32(index), $0, Int32(value.count), SQLITE_TRANSIENT)
        }), statement: sql)
    }

    public func bindNull(_ name: String) throws { try bindNull(bindParameterIndex(name)) }
    public func bind(_ name: String, to value: Int64?) throws { try bind(bindParameterIndex(name), to: value) }
    public func bind(_ name: String, to value: Double?) throws { try bind(bindParameterIndex(name), to: value) }
    public func bind(_ name: String, to value: String?) throws { try bind(bindParameterIndex(name), to: value) }
    public func bind(_ name: String, to value: Data?) throws { try bind(bindParameterIndex(name), to: value) }
}
