import Foundation

enum ImportSourceType: String, Codable {
    case folder
    case file
}

struct ReplayGainInfo: Codable, Equatable {
    var trackGainDb: Double?
    var albumGainDb: Double?
    var peak: Double?
}

struct Track: Identifiable, Codable, Equatable {
    var id: UUID
    var filePath: String
    var bookmarkData: Data?
    var mtime: Date
    var duration: Double
    var sampleRate: Double
    var bitRate: Int
    var format: String
    var title: String
    var artist: String
    var album: String
    var trackNo: Int
    var discNo: Int
    var coverArtPath: String?
    var replayGain: ReplayGainInfo
    var isAvailable: Bool

    var fileURL: URL { URL(fileURLWithPath: filePath) }
}

struct Artist: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var trackCount: Int
}

struct Album: Identifiable, Equatable {
    var id: String { "\(artist)-\(title)" }
    var title: String
    var artist: String
    var trackCount: Int
}

struct ImportSource: Identifiable, Equatable {
    var id: UUID
    var path: String
    var bookmarkData: Data?
    var type: ImportSourceType
    var watchEnabled: Bool
    var createdAt: Date

    var url: URL { URL(fileURLWithPath: path) }
}

struct Playlist: Identifiable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
}

struct TrackStats: Equatable {
    var trackID: UUID
    var isFavorite: Bool
    var playCount: Int
    var lastPlayedAt: Date?
    var skipCount: Int
}

struct HistoryEntry: Identifiable, Equatable {
    var id: UUID
    var trackID: UUID
    var playedAt: Date
    var playedSeconds: Double
}

enum PlaybackStatus: Equatable {
    case stopped
    case loading
    case playing
    case paused
    case failed(String)
}

enum PlaybackMode: String, CaseIterable, Identifiable {
    case sequence = "顺序"
    case shuffle = "随机"
    case repeatOne = "单曲循环"

    var id: String { rawValue }
}

struct PlaybackState: Equatable {
    var status: PlaybackStatus = .stopped
    var currentTrack: Track?
    var position: Double = 0
    var duration: Double = 0
    var volume: Float = 1
    var replayGainEnabled: Bool = true
    var fadeDuration: TimeInterval = 0.25
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case allTracks = "全部歌曲"
    case artists = "艺术家"
    case albums = "专辑"
    case recentlyPlayed = "最近播放"
    case favorites = "收藏"
    case settings = "设置"

    var id: String { rawValue }
}

struct LibraryOperationStatus: Equatable {
    var isRunning: Bool
    var message: String
    var progress: Double?
}
