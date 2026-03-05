import Foundation
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let libraryService: LibraryService
    let playlistService: PlaylistService
    let historyService: HistoryService
    let audioEngine: AudioEngine
    let nowPlayingController: NowPlayingController

    enum ContainerError: Error {
        case databaseInitializationFailed
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent("ApexPlayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let dbPath = root.appendingPathComponent("apex.sqlite").path
        guard let database = try? SQLiteDatabase(path: dbPath) else {
            fatalError("无法初始化数据库: \(dbPath)")
        }

        let trackRepo = SQLiteTrackRepository(database: database)
        let sourceRepo = SQLiteImportSourceRepository(database: database)
        let playlistRepo = SQLitePlaylistRepository(database: database)
        let historyRepo = SQLiteHistoryRepository(database: database)

        self.libraryService = LibraryServiceImpl(trackRepository: trackRepo, sourceRepository: sourceRepo)
        self.playlistService = PlaylistServiceImpl(playlistRepository: playlistRepo, trackRepository: trackRepo)
        self.historyService = HistoryServiceImpl(repository: historyRepo)
        self.audioEngine = AVAudioEnginePlayer()
        self.nowPlayingController = NowPlayingController()
    }
}
