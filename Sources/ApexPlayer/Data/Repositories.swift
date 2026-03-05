import Foundation
import SQLite3

final class SQLiteTrackRepository: TrackRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func upsertTracks(_ tracks: [Track]) throws {
        let sql = """
            INSERT INTO tracks (
                id, file_path, bookmark_data, mtime, duration, sample_rate, bit_rate, format,
                title, artist, album, track_no, disc_no, cover_art_path,
                replaygain_track_db, replaygain_album_db, replaygain_peak,
                is_available, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(file_path) DO UPDATE SET
                bookmark_data = excluded.bookmark_data,
                mtime = excluded.mtime,
                duration = excluded.duration,
                sample_rate = excluded.sample_rate,
                bit_rate = excluded.bit_rate,
                format = excluded.format,
                title = excluded.title,
                artist = excluded.artist,
                album = excluded.album,
                track_no = excluded.track_no,
                disc_no = excluded.disc_no,
                cover_art_path = excluded.cover_art_path,
                replaygain_track_db = excluded.replaygain_track_db,
                replaygain_album_db = excluded.replaygain_album_db,
                replaygain_peak = excluded.replaygain_peak,
                is_available = excluded.is_available,
                updated_at = excluded.updated_at
        """

        for track in tracks {
            let statement = try database.prepare(sql)
            defer { sqlite3_finalize(statement) }

            let now = Date().timeIntervalSince1970
            try SQLiteHelpers.bind(track.id.uuidString, to: 1, in: statement)
            try SQLiteHelpers.bind(track.filePath, to: 2, in: statement)
            try SQLiteHelpers.bind(track.bookmarkData, to: 3, in: statement)
            try SQLiteHelpers.bind(track.mtime.timeIntervalSince1970, to: 4, in: statement)
            try SQLiteHelpers.bind(track.duration, to: 5, in: statement)
            try SQLiteHelpers.bind(track.sampleRate, to: 6, in: statement)
            try SQLiteHelpers.bind(track.bitRate, to: 7, in: statement)
            try SQLiteHelpers.bind(track.format, to: 8, in: statement)
            try SQLiteHelpers.bind(track.title, to: 9, in: statement)
            try SQLiteHelpers.bind(track.artist, to: 10, in: statement)
            try SQLiteHelpers.bind(track.album, to: 11, in: statement)
            try SQLiteHelpers.bind(track.trackNo, to: 12, in: statement)
            try SQLiteHelpers.bind(track.discNo, to: 13, in: statement)
            try SQLiteHelpers.bind(track.coverArtPath, to: 14, in: statement)
            try SQLiteHelpers.bind(track.replayGain.trackGainDb, to: 15, in: statement)
            try SQLiteHelpers.bind(track.replayGain.albumGainDb, to: 16, in: statement)
            try SQLiteHelpers.bind(track.replayGain.peak, to: 17, in: statement)
            try SQLiteHelpers.bind(track.isAvailable ? 1 : 0, to: 18, in: statement)
            try SQLiteHelpers.bind(now, to: 19, in: statement)
            try SQLiteHelpers.bind(now, to: 20, in: statement)

            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
            }
        }
    }

    func fetchTracks() throws -> [Track] {
        let statement = try database.prepare("""
            SELECT id, file_path, bookmark_data, mtime, duration, sample_rate, bit_rate, format,
                   title, artist, album, track_no, disc_no, cover_art_path,
                   replaygain_track_db, replaygain_album_db, replaygain_peak, is_available
            FROM tracks
            ORDER BY artist COLLATE NOCASE, album COLLATE NOCASE, track_no, title COLLATE NOCASE
        """)
        defer { sqlite3_finalize(statement) }

        var tracks: [Track] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = UUID(uuidString: SQLiteHelpers.text(statement, at: 0)) ?? UUID()
            let track = Track(
                id: id,
                filePath: SQLiteHelpers.text(statement, at: 1),
                bookmarkData: SQLiteHelpers.data(statement, at: 2),
                mtime: SQLiteHelpers.date(statement, at: 3),
                duration: sqlite3_column_double(statement, 4),
                sampleRate: sqlite3_column_double(statement, 5),
                bitRate: Int(sqlite3_column_int(statement, 6)),
                format: SQLiteHelpers.text(statement, at: 7),
                title: SQLiteHelpers.text(statement, at: 8),
                artist: SQLiteHelpers.text(statement, at: 9),
                album: SQLiteHelpers.text(statement, at: 10),
                trackNo: Int(sqlite3_column_int(statement, 11)),
                discNo: Int(sqlite3_column_int(statement, 12)),
                coverArtPath: sqlite3_column_type(statement, 13) == SQLITE_NULL ? nil : SQLiteHelpers.text(statement, at: 13),
                replayGain: ReplayGainInfo(
                    trackGainDb: SQLiteHelpers.optionalDouble(statement, at: 14),
                    albumGainDb: SQLiteHelpers.optionalDouble(statement, at: 15),
                    peak: SQLiteHelpers.optionalDouble(statement, at: 16)
                ),
                isAvailable: sqlite3_column_int(statement, 17) == 1
            )
            tracks.append(track)
        }
        return tracks
    }

    func deleteTrack(byPath path: String) throws {
        let statement = try database.prepare("DELETE FROM tracks WHERE file_path = ?")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(path, to: 1, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func clearUnavailableTracks(matching paths: Set<String>) throws {
        guard !paths.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: paths.count).joined(separator: ",")
        let statement = try database.prepare("UPDATE tracks SET is_available = 0 WHERE file_path NOT IN (\(placeholders))")
        defer { sqlite3_finalize(statement) }
        for (offset, path) in paths.enumerated() {
            try SQLiteHelpers.bind(path, to: Int32(offset + 1), in: statement)
        }
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }
}

final class SQLiteImportSourceRepository: ImportSourceRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) { self.database = database }

    func insert(_ source: ImportSource) throws {
        let statement = try database.prepare("""
            INSERT INTO import_sources (id, path, bookmark_data, type, watch_enabled, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                bookmark_data = excluded.bookmark_data,
                type = excluded.type,
                watch_enabled = excluded.watch_enabled
        """)
        defer { sqlite3_finalize(statement) }

        try SQLiteHelpers.bind(source.id.uuidString, to: 1, in: statement)
        try SQLiteHelpers.bind(source.path, to: 2, in: statement)
        try SQLiteHelpers.bind(source.bookmarkData, to: 3, in: statement)
        try SQLiteHelpers.bind(source.type.rawValue, to: 4, in: statement)
        try SQLiteHelpers.bind(source.watchEnabled ? 1 : 0, to: 5, in: statement)
        try SQLiteHelpers.bind(source.createdAt.timeIntervalSince1970, to: 6, in: statement)

        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func fetchAll() throws -> [ImportSource] {
        let statement = try database.prepare("SELECT id, path, bookmark_data, type, watch_enabled, created_at FROM import_sources ORDER BY created_at DESC")
        defer { sqlite3_finalize(statement) }

        var sources: [ImportSource] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let source = ImportSource(
                id: UUID(uuidString: SQLiteHelpers.text(statement, at: 0)) ?? UUID(),
                path: SQLiteHelpers.text(statement, at: 1),
                bookmarkData: SQLiteHelpers.data(statement, at: 2),
                type: ImportSourceType(rawValue: SQLiteHelpers.text(statement, at: 3)) ?? .folder,
                watchEnabled: sqlite3_column_int(statement, 4) == 1,
                createdAt: SQLiteHelpers.date(statement, at: 5)
            )
            sources.append(source)
        }
        return sources
    }
}

final class SQLitePlaylistRepository: PlaylistRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) { self.database = database }

    func create(_ playlist: Playlist) throws {
        let statement = try database.prepare("INSERT INTO playlists (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(playlist.id.uuidString, to: 1, in: statement)
        try SQLiteHelpers.bind(playlist.name, to: 2, in: statement)
        try SQLiteHelpers.bind(playlist.createdAt.timeIntervalSince1970, to: 3, in: statement)
        try SQLiteHelpers.bind(playlist.updatedAt.timeIntervalSince1970, to: 4, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func allPlaylists() throws -> [Playlist] {
        let statement = try database.prepare("SELECT id, name, created_at, updated_at FROM playlists ORDER BY updated_at DESC")
        defer { sqlite3_finalize(statement) }
        var items: [Playlist] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            items.append(Playlist(
                id: UUID(uuidString: SQLiteHelpers.text(statement, at: 0)) ?? UUID(),
                name: SQLiteHelpers.text(statement, at: 1),
                createdAt: SQLiteHelpers.date(statement, at: 2),
                updatedAt: SQLiteHelpers.date(statement, at: 3)
            ))
        }
        return items
    }

    func rename(id: UUID, name: String, updatedAt: Date) throws {
        let statement = try database.prepare("UPDATE playlists SET name = ?, updated_at = ? WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(name, to: 1, in: statement)
        try SQLiteHelpers.bind(updatedAt.timeIntervalSince1970, to: 2, in: statement)
        try SQLiteHelpers.bind(id.uuidString, to: 3, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func delete(id: UUID) throws {
        let statement = try database.prepare("DELETE FROM playlists WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(id.uuidString, to: 1, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func add(trackID: UUID, playlistID: UUID) throws {
        let maxPosStmt = try database.prepare("SELECT COALESCE(MAX(position), -1) FROM playlist_items WHERE playlist_id = ?")
        defer { sqlite3_finalize(maxPosStmt) }
        try SQLiteHelpers.bind(playlistID.uuidString, to: 1, in: maxPosStmt)
        var nextPos = 0
        if sqlite3_step(maxPosStmt) == SQLITE_ROW {
            nextPos = Int(sqlite3_column_int(maxPosStmt, 0)) + 1
        }

        let statement = try database.prepare("INSERT OR REPLACE INTO playlist_items (playlist_id, track_id, position, added_at) VALUES (?, ?, ?, ?)")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(playlistID.uuidString, to: 1, in: statement)
        try SQLiteHelpers.bind(trackID.uuidString, to: 2, in: statement)
        try SQLiteHelpers.bind(nextPos, to: 3, in: statement)
        try SQLiteHelpers.bind(Date().timeIntervalSince1970, to: 4, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func remove(trackID: UUID, playlistID: UUID) throws {
        let statement = try database.prepare("DELETE FROM playlist_items WHERE playlist_id = ? AND track_id = ?")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(playlistID.uuidString, to: 1, in: statement)
        try SQLiteHelpers.bind(trackID.uuidString, to: 2, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func move(playlistID: UUID, from sourceIndex: Int, to destinationIndex: Int) throws {
        var ids = try trackIDs(in: playlistID)
        guard sourceIndex >= 0, sourceIndex < ids.count else { return }
        let moved = ids.remove(at: sourceIndex)
        let destination = max(0, min(destinationIndex, ids.count))
        ids.insert(moved, at: destination)

        try database.execute("BEGIN TRANSACTION;")
        defer { _ = try? database.execute("COMMIT;") }
        for (idx, id) in ids.enumerated() {
            let statement = try database.prepare("UPDATE playlist_items SET position = ? WHERE playlist_id = ? AND track_id = ?")
            defer { sqlite3_finalize(statement) }
            try SQLiteHelpers.bind(idx, to: 1, in: statement)
            try SQLiteHelpers.bind(playlistID.uuidString, to: 2, in: statement)
            try SQLiteHelpers.bind(id.uuidString, to: 3, in: statement)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
            }
        }
    }

    func trackIDs(in playlistID: UUID) throws -> [UUID] {
        let statement = try database.prepare("SELECT track_id FROM playlist_items WHERE playlist_id = ? ORDER BY position ASC")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(playlistID.uuidString, to: 1, in: statement)
        var ids: [UUID] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let id = UUID(uuidString: SQLiteHelpers.text(statement, at: 0)) {
                ids.append(id)
            }
        }
        return ids
    }
}

final class SQLiteHistoryRepository: HistoryRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) { self.database = database }

    func record(_ entry: HistoryEntry) throws {
        let statement = try database.prepare("INSERT INTO play_history (id, track_id, played_at, played_seconds) VALUES (?, ?, ?, ?)")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(entry.id.uuidString, to: 1, in: statement)
        try SQLiteHelpers.bind(entry.trackID.uuidString, to: 2, in: statement)
        try SQLiteHelpers.bind(entry.playedAt.timeIntervalSince1970, to: 3, in: statement)
        try SQLiteHelpers.bind(entry.playedSeconds, to: 4, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func recent(limit: Int) throws -> [HistoryEntry] {
        let statement = try database.prepare("SELECT id, track_id, played_at, played_seconds FROM play_history ORDER BY played_at DESC LIMIT ?")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(limit, to: 1, in: statement)
        var items: [HistoryEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            items.append(HistoryEntry(
                id: UUID(uuidString: SQLiteHelpers.text(statement, at: 0)) ?? UUID(),
                trackID: UUID(uuidString: SQLiteHelpers.text(statement, at: 1)) ?? UUID(),
                playedAt: SQLiteHelpers.date(statement, at: 2),
                playedSeconds: sqlite3_column_double(statement, 3)
            ))
        }
        return items
    }

    func clearHistory() throws {
        try database.execute("DELETE FROM play_history")
    }

    func setFavorite(trackID: UUID, isFavorite: Bool) throws {
        let statement = try database.prepare("""
            INSERT INTO track_stats (track_id, is_favorite, play_count, skip_count)
            VALUES (?, ?, 0, 0)
            ON CONFLICT(track_id) DO UPDATE SET is_favorite = excluded.is_favorite
        """)
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(trackID.uuidString, to: 1, in: statement)
        try SQLiteHelpers.bind(isFavorite ? 1 : 0, to: 2, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func favoriteTrackIDs() throws -> Set<UUID> {
        let statement = try database.prepare("SELECT track_id FROM track_stats WHERE is_favorite = 1")
        defer { sqlite3_finalize(statement) }
        var ids = Set<UUID>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let id = UUID(uuidString: SQLiteHelpers.text(statement, at: 0)) {
                ids.insert(id)
            }
        }
        return ids
    }

    func incrementPlayCount(trackID: UUID, playedAt: Date) throws {
        let statement = try database.prepare("""
            INSERT INTO track_stats (track_id, is_favorite, play_count, last_played_at, skip_count)
            VALUES (?, 0, 1, ?, 0)
            ON CONFLICT(track_id) DO UPDATE SET
                play_count = play_count + 1,
                last_played_at = excluded.last_played_at
        """)
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(trackID.uuidString, to: 1, in: statement)
        try SQLiteHelpers.bind(playedAt.timeIntervalSince1970, to: 2, in: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database.db)))
        }
    }

    func stats(trackID: UUID) throws -> TrackStats? {
        let statement = try database.prepare("SELECT track_id, is_favorite, play_count, last_played_at, skip_count FROM track_stats WHERE track_id = ?")
        defer { sqlite3_finalize(statement) }
        try SQLiteHelpers.bind(trackID.uuidString, to: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return TrackStats(
            trackID: UUID(uuidString: SQLiteHelpers.text(statement, at: 0)) ?? trackID,
            isFavorite: sqlite3_column_int(statement, 1) == 1,
            playCount: Int(sqlite3_column_int(statement, 2)),
            lastPlayedAt: SQLiteHelpers.optionalDate(statement, at: 3),
            skipCount: Int(sqlite3_column_int(statement, 4))
        )
    }
}
