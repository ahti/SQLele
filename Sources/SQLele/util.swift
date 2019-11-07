#if os(Linux)
    import CSQLite
#else
    import SQLite3
#endif

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
