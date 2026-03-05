import Combine
import Foundation

@MainActor
protocol AudioEngine {
    func load(track: Track) async throws
    func play()
    func pause()
    func seek(to seconds: Double)
    func setVolume(_ value: Float)
    func setReplayGain(enabled: Bool)
    func setFade(duration: TimeInterval)
    var statePublisher: AnyPublisher<PlaybackState, Never> { get }
}

@MainActor
protocol LibraryService {
    func addImportSource(_ source: ImportSource) async throws
    func rescanAll() async
    func importFiles(_ urls: [URL]) async
    var tracksPublisher: AnyPublisher<[Track], Never> { get }
    var importSourcesPublisher: AnyPublisher<[ImportSource], Never> { get }
    var operationStatusPublisher: AnyPublisher<LibraryOperationStatus?, Never> { get }
    func currentTracks() -> [Track]
    func currentSources() -> [ImportSource]
}

@MainActor
protocol PlaylistService {
    func createPlaylist(name: String) throws -> Playlist
    func renamePlaylist(id: UUID, name: String) throws
    func deletePlaylist(id: UUID) throws
    func addTrack(_ trackID: UUID, to playlistID: UUID) throws
    func removeTrack(_ trackID: UUID, from playlistID: UUID) throws
    func moveTrack(in playlistID: UUID, from sourceIndex: Int, to destinationIndex: Int) throws
    func playlists() -> [Playlist]
    func tracks(in playlistID: UUID) -> [Track]
}

@MainActor
protocol HistoryService {
    func recordPlay(trackId: UUID, at: Date, playedSeconds: Double)
    func recent(limit: Int) -> [HistoryEntry]
    func clearHistory()
    func markFavorite(trackID: UUID, isFavorite: Bool)
    func favoriteTrackIDs() -> Set<UUID>
    func stats(for trackID: UUID) -> TrackStats?
}

protocol TrackRepository {
    func upsertTracks(_ tracks: [Track]) throws
    func fetchTracks() throws -> [Track]
    func deleteTrack(byPath path: String) throws
    func clearUnavailableTracks(matching paths: Set<String>) throws
}

protocol ImportSourceRepository {
    func insert(_ source: ImportSource) throws
    func fetchAll() throws -> [ImportSource]
}

protocol PlaylistRepository {
    func create(_ playlist: Playlist) throws
    func rename(id: UUID, name: String, updatedAt: Date) throws
    func delete(id: UUID) throws
    func allPlaylists() throws -> [Playlist]
    func add(trackID: UUID, playlistID: UUID) throws
    func remove(trackID: UUID, playlistID: UUID) throws
    func move(playlistID: UUID, from sourceIndex: Int, to destinationIndex: Int) throws
    func trackIDs(in playlistID: UUID) throws -> [UUID]
}

protocol HistoryRepository {
    func record(_ entry: HistoryEntry) throws
    func recent(limit: Int) throws -> [HistoryEntry]
    func clearHistory() throws
    func setFavorite(trackID: UUID, isFavorite: Bool) throws
    func favoriteTrackIDs() throws -> Set<UUID>
    func incrementPlayCount(trackID: UUID, playedAt: Date) throws
    func stats(trackID: UUID) throws -> TrackStats?
}
