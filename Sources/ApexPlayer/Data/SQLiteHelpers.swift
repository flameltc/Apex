import Foundation
import SQLite3

enum SQLiteHelpers {
    static func bind(_ value: String?, to index: Int32, in statement: OpaquePointer?) throws {
        if let value {
            guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else { throw DatabaseError.bindFailed }
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else { throw DatabaseError.bindFailed }
        }
    }

    static func bind(_ value: Double?, to index: Int32, in statement: OpaquePointer?) throws {
        if let value {
            guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else { throw DatabaseError.bindFailed }
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else { throw DatabaseError.bindFailed }
        }
    }

    static func bind(_ value: Int, to index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_int64(statement, index, sqlite3_int64(value)) == SQLITE_OK else { throw DatabaseError.bindFailed }
    }

    static func bind(_ value: Data?, to index: Int32, in statement: OpaquePointer?) throws {
        if let value {
            let count = Int32(value.count)
            let result = value.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, index, buffer.baseAddress, count, SQLITE_TRANSIENT)
            }
            guard result == SQLITE_OK else { throw DatabaseError.bindFailed }
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else { throw DatabaseError.bindFailed }
        }
    }

    static func text(_ statement: OpaquePointer?, at index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    static func data(_ statement: OpaquePointer?, at index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
        let length = Int(sqlite3_column_bytes(statement, index))
        return Data(bytes: bytes, count: length)
    }

    static func date(_ statement: OpaquePointer?, at index: Int32) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    static func optionalDate(_ statement: OpaquePointer?, at index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    static func optionalDouble(_ statement: OpaquePointer?, at index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
