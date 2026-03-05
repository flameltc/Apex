import Foundation
import SQLite3

final class SQLiteDatabase {
    private(set) var db: OpaquePointer?
    private let path: String

    init(path: String) throws {
        self.path = path
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw DatabaseError.openFailed
        }
        try execute("PRAGMA foreign_keys = ON;")
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.execFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private func migrate() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS tracks (
                id TEXT PRIMARY KEY,
                file_path TEXT UNIQUE NOT NULL,
                bookmark_data BLOB,
                mtime REAL NOT NULL,
                duration REAL NOT NULL,
                sample_rate REAL NOT NULL,
                bit_rate INTEGER NOT NULL,
                format TEXT NOT NULL,
                title TEXT NOT NULL,
                artist TEXT NOT NULL,
                album TEXT NOT NULL,
                track_no INTEGER NOT NULL,
                disc_no INTEGER NOT NULL,
                cover_art_path TEXT,
                replaygain_track_db REAL,
                replaygain_album_db REAL,
                replaygain_peak REAL,
                is_available INTEGER NOT NULL DEFAULT 1,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );

            CREATE TABLE IF NOT EXISTS import_sources (
                id TEXT PRIMARY KEY,
                path TEXT UNIQUE NOT NULL,
                bookmark_data BLOB,
                type TEXT NOT NULL,
                watch_enabled INTEGER NOT NULL,
                created_at REAL NOT NULL
            );

            CREATE TABLE IF NOT EXISTS playlists (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );

            CREATE TABLE IF NOT EXISTS playlist_items (
                playlist_id TEXT NOT NULL,
                track_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                added_at REAL NOT NULL,
                PRIMARY KEY (playlist_id, track_id),
                FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
                FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS track_stats (
                track_id TEXT PRIMARY KEY,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                play_count INTEGER NOT NULL DEFAULT 0,
                last_played_at REAL,
                skip_count INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS play_history (
                id TEXT PRIMARY KEY,
                track_id TEXT NOT NULL,
                played_at REAL NOT NULL,
                played_seconds REAL NOT NULL,
                FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
            );
        """)
    }
}

enum DatabaseError: Error {
    case openFailed
    case prepareFailed(message: String)
    case execFailed(message: String)
    case bindFailed
    case stepFailed(message: String)
}
