import XCTest
@testable import ApexPlayer

final class SQLiteRepositoryTests: XCTestCase {
    private var tempDBPath: String!
    private var database: SQLiteDatabase!

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDBPath = dir.appendingPathComponent("test.sqlite").path
        database = try SQLiteDatabase(path: tempDBPath)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: (tempDBPath as NSString).deletingLastPathComponent)
    }

    func testTrackUpsertAndFetch() throws {
        let repo = SQLiteTrackRepository(database: database)
        let track = Track(
            id: UUID(),
            filePath: "/tmp/test.mp3",
            bookmarkData: nil,
            mtime: Date(),
            duration: 180,
            sampleRate: 44_100,
            bitRate: 320_000,
            format: "mp3",
            title: "Song",
            artist: "Artist",
            album: "Album",
            trackNo: 1,
            discNo: 1,
            coverArtPath: nil,
            replayGain: ReplayGainInfo(trackGainDb: -5, albumGainDb: nil, peak: nil),
            isAvailable: true
        )

        try repo.upsertTracks([track])
        let fetched = try repo.fetchTracks()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Song")
        XCTAssertEqual(fetched[0].replayGain.trackGainDb, -5)
    }

    func testFavoritePersistence() throws {
        let trackRepo = SQLiteTrackRepository(database: database)
        let existingTrack = Track(
            id: UUID(),
            filePath: "/tmp/favorite.mp3",
            bookmarkData: nil,
            mtime: Date(),
            duration: 120,
            sampleRate: 44_100,
            bitRate: 256_000,
            format: "mp3",
            title: "Fav Song",
            artist: "Fav Artist",
            album: "Fav Album",
            trackNo: 1,
            discNo: 1,
            coverArtPath: nil,
            replayGain: ReplayGainInfo(trackGainDb: nil, albumGainDb: nil, peak: nil),
            isAvailable: true
        )
        try trackRepo.upsertTracks([existingTrack])

        let historyRepo = SQLiteHistoryRepository(database: database)
        let trackID = existingTrack.id

        try historyRepo.setFavorite(trackID: trackID, isFavorite: true)
        let ids = try historyRepo.favoriteTrackIDs()

        XCTAssertTrue(ids.contains(trackID))
    }
}
