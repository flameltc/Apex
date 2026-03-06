import AppKit
import Combine
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    enum ThemeMode: String, CaseIterable, Identifiable {
        case light = "浅色"
        case dark = "深色"

        var id: String { rawValue }
    }

    enum SidebarSelection: Hashable {
        case section(LibrarySection)
        case playlist(UUID)
    }

    struct RecentTrackRow: Identifiable {
        var id: UUID { entry.id }
        let entry: HistoryEntry
        let track: Track
    }

    struct RecentSection: Identifiable {
        let date: Date
        let rows: [RecentTrackRow]
        var id: Date { date }
    }

    struct ArtistSummary: Identifiable {
        var id: String { name }
        let name: String
        let trackCount: Int
    }

    struct AlbumSummary: Identifiable {
        var id: String { "\(artist)-\(title)" }
        let title: String
        let artist: String
        let trackCount: Int
    }

    struct TrackGroup: Identifiable {
        let title: String
        let tracks: [Track]
        var id: String { title }
    }

    @Published var sidebarSelection: SidebarSelection = .section(.allTracks)
    @Published var selectedTrackID: UUID?
    @Published var selectedPlaylistTrackIDs: Set<UUID> = []
    @Published var selectedArtistName: String?
    @Published var selectedAlbumID: String?
    @Published var searchText = ""
    @Published var tracks: [Track] = []
    @Published var importSources: [ImportSource] = []
    @Published var playbackState = PlaybackState()
    @Published var playlists: [Playlist] = []
    @Published var favorites: Set<UUID> = []
    @Published var isReplayingGainEnabled = true
    @Published var fadeDurationMs: Double = 250
    @Published var themeMode: ThemeMode = .dark
    @Published var playbackMode: PlaybackMode = .sequence
    @Published var isQueuePresented = false
    @Published var queueTrackIDs: [UUID] = []
    @Published var libraryOperationStatus: String?
    @Published var libraryOperationProgress: Double?
    @Published var isLibraryBusy = false
    @Published var currentError: String?
    @Published private var historyRefreshToken = UUID()

    private let libraryService: LibraryService
    private let playlistService: PlaylistService
    private let historyService: HistoryService
    private let audioEngine: AudioEngine
    private let nowPlayingController: NowPlayingController
    private let defaults: UserDefaults

    private var cancellables: Set<AnyCancellable> = []

    private enum SettingsKey {
        static let replayGainEnabled = "settings.replayGainEnabled"
        static let fadeDurationMs = "settings.fadeDurationMs"
        static let themeMode = "settings.themeMode"
        static let playbackMode = "playback.mode"
        static let lastTrackID = "playback.lastTrackID"
        static let lastPosition = "playback.lastPosition"
        static let queueTrackIDs = "playback.queueTrackIDs"
    }

    private var pendingRestore: (trackID: UUID, position: Double)?
    private var previousPlaybackStatus: PlaybackStatus = .stopped

    convenience init(container: AppContainer, defaults: UserDefaults = .standard) {
        self.init(
            libraryService: container.libraryService,
            playlistService: container.playlistService,
            historyService: container.historyService,
            audioEngine: container.audioEngine,
            nowPlayingController: container.nowPlayingController,
            defaults: defaults
        )
    }

    init(
        libraryService: LibraryService,
        playlistService: PlaylistService,
        historyService: HistoryService,
        audioEngine: AudioEngine,
        nowPlayingController: NowPlayingController,
        defaults: UserDefaults = .standard,
        enableRemoteCommands: Bool = true
    ) {
        self.libraryService = libraryService
        self.playlistService = playlistService
        self.historyService = historyService
        self.audioEngine = audioEngine
        self.nowPlayingController = nowPlayingController
        self.defaults = defaults

        bind()
        if enableRemoteCommands {
            setupRemoteControl()
        }
        playlists = playlistService.playlists()
        favorites = historyService.favoriteTrackIDs()
        loadSettings()
    }

    var selectedSection: LibrarySection? {
        if case let .section(section) = sidebarSelection { return section }
        return nil
    }

    var selectedPlaylist: Playlist? {
        guard case let .playlist(id) = sidebarSelection else { return nil }
        return playlists.first { $0.id == id }
    }

    var filteredTracks: [Track] {
        let base = baseTracksForSelection()
        if searchText.isEmpty { return base }
        let q = searchText.lowercased()
        return base.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
        }
    }

    var recentTrackRows: [RecentTrackRow] {
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return historyService.recent(limit: 200).compactMap { entry in
            guard let track = byID[entry.trackID] else { return nil }
            return RecentTrackRow(entry: entry, track: track)
        }
    }

    var recentSections: [RecentSection] {
        _ = historyRefreshToken
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentTrackRows) { row in
            calendar.startOfDay(for: row.entry.playedAt)
        }
        return grouped.keys.sorted(by: >).map { day in
            RecentSection(date: day, rows: grouped[day] ?? [])
        }
    }

    var artistSummaries: [ArtistSummary] {
        let grouped = Dictionary(grouping: tracks) { $0.artist.isEmpty ? "Unknown Artist" : $0.artist }
        return grouped.map { ArtistSummary(name: $0.key, trackCount: $0.value.count) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var albumSummaries: [AlbumSummary] {
        let grouped = Dictionary(grouping: tracks) { "\($0.artist)|\($0.album)" }
        return grouped.compactMap { _, items in
            guard let first = items.first else { return nil }
            return AlbumSummary(
                title: first.album.isEmpty ? "Unknown Album" : first.album,
                artist: first.artist.isEmpty ? "Unknown Artist" : first.artist,
                trackCount: items.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.artist.caseInsensitiveCompare(rhs.artist) == .orderedSame {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.artist.localizedCaseInsensitiveCompare(rhs.artist) == .orderedAscending
        }
    }

    var selectedTrack: Track? {
        guard let id = selectedTrackID else { return nil }
        return filteredTracks.first { $0.id == id } ?? tracks.first { $0.id == id }
    }

    var detailTitle: String {
        if let section = selectedSection { return section.rawValue }
        return selectedPlaylist?.name ?? "播放列表"
    }

    var queueCurrentTrack: Track? {
        playbackState.currentTrack
    }

    var queueUpNextTracks: [Track] {
        let trackMap = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return queueTrackIDs.compactMap { trackMap[$0] }
    }

    var isArtistDrillDown: Bool {
        selectedSection == .artists && selectedArtistName != nil
    }

    var isAlbumDrillDown: Bool {
        selectedSection == .albums && selectedAlbumID != nil
    }

    var artistDetailTracks: [Track] {
        guard let artist = selectedArtistName else { return [] }
        return tracks
            .filter { normalizeArtist($0.artist) == artist }
            .sorted { lhs, rhs in
                if lhs.album.caseInsensitiveCompare(rhs.album) == .orderedSame {
                    return lhs.trackNo < rhs.trackNo
                }
                return lhs.album.localizedCaseInsensitiveCompare(rhs.album) == .orderedAscending
            }
    }

    var albumDetailTracks: [Track] {
        guard let albumID = selectedAlbumID else { return [] }
        return tracks
            .filter { albumKey(artist: $0.artist, album: $0.album) == albumID }
            .sorted { lhs, rhs in
                if lhs.discNo == rhs.discNo { return lhs.trackNo < rhs.trackNo }
                return lhs.discNo < rhs.discNo
            }
    }

    var artistTrackGroups: [TrackGroup] {
        let grouped = Dictionary(grouping: artistDetailTracks) { normalizeAlbum($0.album) }
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { key in
                TrackGroup(title: key, tracks: grouped[key] ?? [])
            }
    }

    var albumTrackGroups: [TrackGroup] {
        let grouped = Dictionary(grouping: albumDetailTracks) { max($0.discNo, 1) }
        return grouped.keys.sorted().map { discNo in
            TrackGroup(title: "Disc \(discNo)", tracks: grouped[discNo] ?? [])
        }
    }

    var artistDetailTitle: String {
        selectedArtistName ?? "艺术家"
    }

    var albumDetailTitle: String {
        guard let albumID = selectedAlbumID else { return "专辑" }
        if let summary = albumSummaries.first(where: { $0.id == albumID }) {
            return "\(summary.artist) · \(summary.title)"
        }
        return "专辑"
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            Task {
                let urls = panel.urls
                guard !urls.isEmpty else { return }
                for url in urls {
                    let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                    let source = ImportSource(id: UUID(), path: url.path, bookmarkData: bookmark, type: .folder, watchEnabled: true, createdAt: Date())
                    try? await libraryService.addImportSource(source)
                }
            }
        }
    }

    func importFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            Task {
                let urls = panel.urls
                guard !urls.isEmpty else { return }
                await libraryService.importFiles(urls)
            }
        }
    }

    func rescanAll() {
        Task { await libraryService.rescanAll() }
    }

    func selectSection(_ section: LibrarySection) {
        sidebarSelection = .section(section)
        selectedArtistName = nil
        selectedAlbumID = nil
    }

    func openArtist(_ artistName: String) {
        selectedArtistName = artistName
        selectedAlbumID = nil
    }

    func backFromArtist() {
        selectedArtistName = nil
    }

    func openAlbum(_ albumID: String) {
        selectedAlbumID = albumID
        selectedArtistName = nil
    }

    func backFromAlbum() {
        selectedAlbumID = nil
    }

    func toggleFavorite(_ trackID: UUID) {
        let newValue = !favorites.contains(trackID)
        historyService.markFavorite(trackID: trackID, isFavorite: newValue)
        favorites = historyService.favoriteTrackIDs()
    }

    func isFavorite(_ trackID: UUID) -> Bool {
        favorites.contains(trackID)
    }

    func createPlaylist(name: String) {
        do {
            let playlist = try playlistService.createPlaylist(name: name)
            playlists = playlistService.playlists()
            sidebarSelection = .playlist(playlist.id)
        } catch {
            currentError = "创建播放列表失败: \(error.localizedDescription)"
        }
    }

    func renamePlaylist(id: UUID, name: String) {
        do {
            try playlistService.renamePlaylist(id: id, name: name)
            playlists = playlistService.playlists()
        } catch {
            currentError = "重命名播放列表失败"
        }
    }

    func deletePlaylist(id: UUID) {
        do {
            try playlistService.deletePlaylist(id: id)
            playlists = playlistService.playlists()
            if case let .playlist(selectedID) = sidebarSelection, selectedID == id {
                sidebarSelection = .section(.allTracks)
            }
        } catch {
            currentError = "删除播放列表失败"
        }
    }

    func addSelectedTrack(to playlist: Playlist) {
        guard let trackID = selectedTrackID else { return }
        do {
            try playlistService.addTrack(trackID, to: playlist.id)
        } catch {
            currentError = "添加到播放列表失败"
        }
    }

    func addTrack(_ trackID: UUID, to playlist: Playlist) {
        do {
            try playlistService.addTrack(trackID, to: playlist.id)
        } catch {
            currentError = "添加到播放列表失败"
        }
    }

    func removeSelectedTrackFromCurrentPlaylist() {
        guard let playlist = selectedPlaylist, let trackID = selectedTrackID else { return }
        do {
            try playlistService.removeTrack(trackID, from: playlist.id)
            selectedPlaylistTrackIDs.remove(trackID)
        } catch {
            currentError = "从播放列表移除失败"
        }
    }

    func removeSelectedTracksFromCurrentPlaylist() {
        guard let playlist = selectedPlaylist, !selectedPlaylistTrackIDs.isEmpty else { return }
        do {
            for trackID in selectedPlaylistTrackIDs {
                try playlistService.removeTrack(trackID, from: playlist.id)
            }
            selectedPlaylistTrackIDs.removeAll()
            selectedTrackID = nil
        } catch {
            currentError = "批量移除失败"
        }
    }

    func clearHistory() {
        historyService.clearHistory()
        historyRefreshToken = UUID()
    }

    func movePlaylistTrack(from sourceOffsets: IndexSet, to destination: Int) {
        guard let playlist = selectedPlaylist, let sourceIndex = sourceOffsets.first else { return }
        do {
            try playlistService.moveTrack(in: playlist.id, from: sourceIndex, to: destination)
        } catch {
            currentError = "播放列表排序失败"
        }
    }

    func playSelected() {
        guard let track = selectedTrack else { return }
        rebuildQueue(forCurrentTrackID: track.id)
        startPlayback(track)
    }

    private func startPlayback(_ track: Track) {
        Task {
            do {
                try await audioEngine.load(track: track)
                audioEngine.play()
            } catch {
                currentError = "播放失败: \(error.localizedDescription)"
            }
        }
    }

    func playTrack(_ track: Track) {
        selectedTrackID = track.id
        selectedPlaylistTrackIDs = [track.id]
        playSelected()
    }

    func togglePlayPause() {
        switch playbackState.status {
        case .playing:
            audioEngine.pause()
        case .paused, .stopped:
            if playbackState.currentTrack == nil {
                playSelected()
            } else {
                audioEngine.play()
            }
        default:
            break
        }
    }

    func handleSpaceKeyToggle() {
        if let selected = selectedTrack,
           selected.id != playbackState.currentTrack?.id {
            rebuildQueue(forCurrentTrackID: selected.id)
            startPlayback(selected)
            return
        }
        togglePlayPause()
    }

    func playNext() {
        guard !filteredTracks.isEmpty else { return }
        playNextInternal(manual: true)
    }

    func playPrevious() {
        guard !filteredTracks.isEmpty else { return }
        let currentIndex = filteredTracks.firstIndex { $0.id == playbackState.currentTrack?.id } ?? 0
        let previousIndex = (currentIndex - 1 + filteredTracks.count) % filteredTracks.count
        let previous = filteredTracks[previousIndex]
        selectedTrackID = previous.id
        playSelected()
    }

    func setVolume(_ volume: Float) {
        audioEngine.setVolume(volume)
    }

    func seek(_ value: Double) {
        let duration = playbackState.duration
        let clamped = min(max(0, value), duration > 0 ? duration : value)
        audioEngine.seek(to: clamped)
    }

    func setReplayGainEnabled(_ enabled: Bool) {
        isReplayingGainEnabled = enabled
        defaults.set(enabled, forKey: SettingsKey.replayGainEnabled)
        audioEngine.setReplayGain(enabled: enabled)
    }

    func setFadeDuration(ms: Double) {
        fadeDurationMs = ms
        defaults.set(ms, forKey: SettingsKey.fadeDurationMs)
        audioEngine.setFade(duration: ms / 1000)
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        defaults.set(mode.rawValue, forKey: SettingsKey.themeMode)
    }

    func setPlaybackMode(_ mode: PlaybackMode) {
        playbackMode = mode
        defaults.set(mode.rawValue, forKey: SettingsKey.playbackMode)
        if let currentID = playbackState.currentTrack?.id {
            rebuildQueue(forCurrentTrackID: currentID)
        }
    }

    func playFromQueue(_ track: Track) {
        queueTrackIDs.removeAll { $0 == track.id }
        persistQueueState()
        selectedTrackID = track.id
        startPlayback(track)
    }

    func moveQueueTrack(from sourceOffsets: IndexSet, to destination: Int) {
        var reordered = queueTrackIDs
        let moving = sourceOffsets.sorted().map { reordered[$0] }
        for index in sourceOffsets.sorted(by: >) {
            reordered.remove(at: index)
        }
        var target = destination
        for source in sourceOffsets {
            if source < destination { target -= 1 }
        }
        reordered.insert(contentsOf: moving, at: max(0, min(target, reordered.count)))
        queueTrackIDs = reordered
        persistQueueState()
    }

    func removeQueueTrack(_ trackID: UUID) {
        queueTrackIDs.removeAll { $0 == trackID }
        persistQueueState()
    }

    func clearQueue() {
        queueTrackIDs.removeAll()
        persistQueueState()
    }

    private func bind() {
        libraryService.tracksPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                self?.tracks = tracks
                self?.restoreLastPlaybackIfNeeded()
            }
            .store(in: &cancellables)

        libraryService.importSourcesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.importSources = $0 }
            .store(in: &cancellables)

        libraryService.operationStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isLibraryBusy = status?.isRunning ?? false
                self?.libraryOperationStatus = status?.message
                self?.libraryOperationProgress = status?.progress
            }
            .store(in: &cancellables)

        audioEngine.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let oldStatus = self.previousPlaybackStatus
                self.playbackState = state
                self.nowPlayingController.update(state: state)
                self.persistLastPlayback(state)
                self.persistHistoryIfNeeded(state)
                self.handleTrackFinishedIfNeeded(oldStatus: oldStatus, newStatus: state.status)
                self.previousPlaybackStatus = state.status
            }
            .store(in: &cancellables)
    }

    private func setupRemoteControl() {
        nowPlayingController.installRemoteCommands(
            onPlay: { [weak self] in self?.togglePlayPause() },
            onPause: { [weak self] in self?.togglePlayPause() },
            onNext: { [weak self] in self?.playNext() },
            onPrevious: { [weak self] in self?.playPrevious() }
        )
    }

    private func persistHistoryIfNeeded(_ state: PlaybackState) {
        guard case .playing = state.status,
              let track = state.currentTrack,
              track.duration > 0,
              state.position > min(30, track.duration * 0.5) else { return }
        if let stats = historyService.stats(for: track.id),
           let last = stats.lastPlayedAt,
           Date().timeIntervalSince(last) < 15 {
            return
        }
        historyService.recordPlay(trackId: track.id, at: Date(), playedSeconds: state.position)
    }

    private func loadSettings() {
        if defaults.object(forKey: SettingsKey.replayGainEnabled) != nil {
            isReplayingGainEnabled = defaults.bool(forKey: SettingsKey.replayGainEnabled)
        }
        if defaults.object(forKey: SettingsKey.fadeDurationMs) != nil {
            fadeDurationMs = defaults.double(forKey: SettingsKey.fadeDurationMs)
        }
        if let rawTheme = defaults.string(forKey: SettingsKey.themeMode),
           let mode = ThemeMode(rawValue: rawTheme) {
            themeMode = mode
        }
        if let raw = defaults.string(forKey: SettingsKey.playbackMode),
           let mode = PlaybackMode(rawValue: raw) {
            playbackMode = mode
        }
        audioEngine.setReplayGain(enabled: isReplayingGainEnabled)
        audioEngine.setFade(duration: fadeDurationMs / 1000)

        if let idString = defaults.string(forKey: SettingsKey.lastTrackID),
           let id = UUID(uuidString: idString) {
            let position = defaults.double(forKey: SettingsKey.lastPosition)
            pendingRestore = (trackID: id, position: position)
        }
        if let rawQueue = defaults.array(forKey: SettingsKey.queueTrackIDs) as? [String] {
            queueTrackIDs = rawQueue.compactMap(UUID.init(uuidString:))
        }
    }

    private func baseTracksForSelection() -> [Track] {
        if case let .playlist(id) = sidebarSelection {
            return playlistService.tracks(in: id)
        }

        switch selectedSection ?? .allTracks {
        case .allTracks, .artists, .albums:
            return tracks
        case .favorites:
            return tracks.filter { favorites.contains($0.id) }
        case .recentlyPlayed:
            let recentIDs = historyService.recent(limit: 100).map(\.trackID)
            let set = Set(recentIDs)
            return tracks.filter { set.contains($0.id) }.sorted { lhs, rhs in
                (recentIDs.firstIndex(of: lhs.id) ?? Int.max) < (recentIDs.firstIndex(of: rhs.id) ?? Int.max)
            }
        case .settings:
            return []
        }
    }

    var isLibraryEmpty: Bool {
        tracks.isEmpty && importSources.isEmpty
    }

    private func normalizeArtist(_ value: String) -> String {
        value.isEmpty ? "Unknown Artist" : value
    }

    private func normalizeAlbum(_ value: String) -> String {
        value.isEmpty ? "Unknown Album" : value
    }

    private func albumKey(artist: String, album: String) -> String {
        "\(normalizeArtist(artist))-\(normalizeAlbum(album))"
    }

    private func persistLastPlayback(_ state: PlaybackState) {
        guard let track = state.currentTrack else { return }
        switch state.status {
        case .playing, .paused:
            defaults.set(track.id.uuidString, forKey: SettingsKey.lastTrackID)
            defaults.set(state.position, forKey: SettingsKey.lastPosition)
        default:
            break
        }
    }

    private func restoreLastPlaybackIfNeeded() {
        guard let pending = pendingRestore else { return }
        guard let track = tracks.first(where: { $0.id == pending.trackID }) else { return }
        pendingRestore = nil
        selectedTrackID = track.id
        Task {
            try? await audioEngine.load(track: track)
            audioEngine.seek(to: pending.position)
        }
    }

    private func playNextInternal(manual: Bool) {
        if !manual && playbackMode == .repeatOne, let current = playbackState.currentTrack {
            startPlayback(current)
            return
        }

        if queueTrackIDs.isEmpty, let currentID = playbackState.currentTrack?.id {
            rebuildQueue(forCurrentTrackID: currentID)
        }

        guard let nextID = queueTrackIDs.first else { return }
        queueTrackIDs.removeFirst()
        guard let nextTrack = tracks.first(where: { $0.id == nextID }) else {
            playNextInternal(manual: manual)
            return
        }
        selectedTrackID = nextTrack.id
        startPlayback(nextTrack)
    }

    private func handleTrackFinishedIfNeeded(oldStatus: PlaybackStatus, newStatus: PlaybackStatus) {
        guard oldStatus == .playing, newStatus == .stopped else { return }
        playNextInternal(manual: false)
    }

    private func rebuildQueue(forCurrentTrackID currentID: UUID) {
        let list = filteredTracks
        guard !list.isEmpty else {
            queueTrackIDs = []
            return
        }
        guard let index = list.firstIndex(where: { $0.id == currentID }) else {
            queueTrackIDs = list.map(\.id)
            return
        }

        switch playbackMode {
        case .sequence, .repeatOne:
            if list.count == 1 {
                queueTrackIDs = []
            } else {
                let tail = Array(list[(index + 1)...])
                let head = Array(list[..<index])
                queueTrackIDs = (tail + head).map(\.id)
            }
        case .shuffle:
            let others = list.enumerated().filter { $0.offset != index }.map(\.element)
            queueTrackIDs = others.shuffled().map(\.id)
        }
        persistQueueState()
    }

    private func persistQueueState() {
        defaults.set(queueTrackIDs.map(\.uuidString), forKey: SettingsKey.queueTrackIDs)
    }
}
