import Foundation

final class PlaylistServiceImpl: PlaylistService {
    private let playlistRepository: PlaylistRepository
    private let trackRepository: TrackRepository

    init(playlistRepository: PlaylistRepository, trackRepository: TrackRepository) {
        self.playlistRepository = playlistRepository
        self.trackRepository = trackRepository
    }

    func createPlaylist(name: String) throws -> Playlist {
        let playlist = Playlist(id: UUID(), name: name, createdAt: Date(), updatedAt: Date())
        try playlistRepository.create(playlist)
        return playlist
    }

    func renamePlaylist(id: UUID, name: String) throws {
        try playlistRepository.rename(id: id, name: name, updatedAt: Date())
    }

    func deletePlaylist(id: UUID) throws {
        try playlistRepository.delete(id: id)
    }

    func addTrack(_ trackID: UUID, to playlistID: UUID) throws {
        try playlistRepository.add(trackID: trackID, playlistID: playlistID)
    }

    func removeTrack(_ trackID: UUID, from playlistID: UUID) throws {
        try playlistRepository.remove(trackID: trackID, playlistID: playlistID)
    }

    func moveTrack(in playlistID: UUID, from sourceIndex: Int, to destinationIndex: Int) throws {
        try playlistRepository.move(playlistID: playlistID, from: sourceIndex, to: destinationIndex)
    }

    func playlists() -> [Playlist] {
        (try? playlistRepository.allPlaylists()) ?? []
    }

    func tracks(in playlistID: UUID) -> [Track] {
        let ids = (try? playlistRepository.trackIDs(in: playlistID)) ?? []
        let allTracks = (try? trackRepository.fetchTracks()) ?? []
        let map = Dictionary(uniqueKeysWithValues: allTracks.map { ($0.id, $0) })
        return ids.compactMap { map[$0] }
    }
}

final class HistoryServiceImpl: HistoryService {
    private let repository: HistoryRepository

    init(repository: HistoryRepository) {
        self.repository = repository
    }

    func recordPlay(trackId: UUID, at: Date, playedSeconds: Double) {
        let entry = HistoryEntry(id: UUID(), trackID: trackId, playedAt: at, playedSeconds: playedSeconds)
        try? repository.record(entry)
        try? repository.incrementPlayCount(trackID: trackId, playedAt: at)
    }

    func recent(limit: Int) -> [HistoryEntry] {
        (try? repository.recent(limit: limit)) ?? []
    }

    func clearHistory() {
        try? repository.clearHistory()
    }

    func markFavorite(trackID: UUID, isFavorite: Bool) {
        try? repository.setFavorite(trackID: trackID, isFavorite: isFavorite)
    }

    func favoriteTrackIDs() -> Set<UUID> {
        (try? repository.favoriteTrackIDs()) ?? []
    }

    func stats(for trackID: UUID) -> TrackStats? {
        try? repository.stats(trackID: trackID)
    }
}
