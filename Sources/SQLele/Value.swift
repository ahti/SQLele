import SQLite3
import Foundation

public protocol SQLValue: SQLConvertible {}
extension Data: SQLValue, SQLConvertible {}
extension Double: SQLValue {}
extension Int64: SQLValue, SQLConvertible {}
extension String: SQLValue, SQLConvertible {}

public enum SQLConversionError: Error {
    case unexpectedType(got: Any.Type, expected: [Any.Type])
    case unknownColumn(name: String)
    case unexpectedNull
}

public protocol SQLConvertible {
    static func fromSQLValue(_ value: SQLValue) throws -> Self
    var sqlValue: SQLValue { get }
}

extension SQLValue {
    public static func fromSQLValue(_ value: SQLValue) throws -> Self {
        guard let v = value as? Self else {
            throw SQLConversionError.unexpectedType(got: type(of: value), expected: [Self.self])
        }
        return v
    }

    public var sqlValue: SQLValue {
        return self
    }
}

extension Double: SQLConvertible {
    public static func fromSQLValue(_ value: SQLValue) throws -> Double {
        switch value {
        case let d as Double: return d
        case let i as Int64: return Double(i)
        default: throw SQLConversionError.unexpectedType(got: type(of: value), expected: [Double.self, Int64.self])
        }
    }

    public var sqlValue: SQLValue {
        return self
    }
}

extension NSNumber: SQLConvertible {
    public static func fromSQLValue(_ value: SQLValue) throws -> Self {
        switch value {
        case let d as Double: return self.init(value: d)
        case let i as Int64: return self.init(value: i)
        default: throw SQLConversionError.unexpectedType(got: type(of: value), expected: [Double.self, Int64.self])
        }
    }

    public var sqlValue: SQLValue {
        let t = String(cString: UnsafePointer(objCType))
        if t == "f" || t == "d" {
            return doubleValue
        } else {
            return int64Value
        }
    }
}

extension Date: SQLConvertible {
    public static func fromSQLValue(_ value: SQLValue) throws -> Date {
        switch value {
        case let d as Double: return Date(timeIntervalSince1970: TimeInterval(d))
        case let i as Int64: return Date(timeIntervalSince1970: TimeInterval(i))
        default: throw SQLConversionError.unexpectedType(got: type(of: value), expected: [Double.self, Int64.self])
        }
    }

    public var sqlValue: SQLValue {
        return timeIntervalSince1970
    }
}

extension Bool: SQLConvertible {
    public static func fromSQLValue(_ value: SQLValue) throws -> Bool {
        switch value {
        case let i as Int64: return i != 0
        default: throw SQLConversionError.unexpectedType(got: type(of: value), expected: [Int64.self])
        }
    }

    public var sqlValue: SQLValue {
        return self ? Int64(1) : Int64(0)
    }
}

extension Int: SQLConvertible {
    public static func fromSQLValue(_ value: SQLValue) throws -> Int {
        switch value {
        case let i as Int64: return Int(i)
        default: throw SQLConversionError.unexpectedType(got: type(of: value), expected: [Int64.self])
        }
    }

    public var sqlValue: SQLValue {
        return Int64(self)
    }
}
