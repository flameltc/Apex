import Combine
import Foundation
import XCTest
@testable import ApexPlayer

@MainActor
final class MainViewModelQueueTests: XCTestCase {
    private func makeTrack(_ id: UUID, title: String, artist: String = "A", album: String = "B", no: Int = 1) -> Track {
        Track(
            id: id,
            filePath: "/tmp/\(id.uuidString).mp3",
            bookmarkData: nil,
            mtime: Date(),
            duration: 120,
            sampleRate: 44_100,
            bitRate: 320_000,
            format: "mp3",
            title: title,
            artist: artist,
            album: album,
            trackNo: no,
            discNo: 1,
            coverArtPath: nil,
            replayGain: ReplayGainInfo(trackGainDb: nil, albumGainDb: nil, peak: nil),
            isAvailable: true
        )
    }

    func testQueuePersistAndMutate() async {
        let t1 = makeTrack(UUID(), title: "t1", no: 1)
        let t2 = makeTrack(UUID(), title: "t2", no: 2)
        let t3 = makeTrack(UUID(), title: "t3", no: 3)

        let suiteName = "test.queue.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let vm = MainViewModel(
            libraryService: FakeLibraryService(tracks: [t1, t2, t3]),
            playlistService: FakePlaylistService(),
            historyService: FakeHistoryService(),
            audioEngine: FakeAudioEngine(),
            nowPlayingController: NowPlayingController(),
            defaults: defaults,
            enableRemoteCommands: false
        )

        await Task.yield()
        vm.selectedTrackID = t1.id
        vm.playSelected()

        XCTAssertEqual(vm.queueTrackIDs, [t2.id, t3.id])
        XCTAssertEqual(defaults.array(forKey: "playback.queueTrackIDs") as? [String], [t2.id.uuidString, t3.id.uuidString])

        vm.removeQueueTrack(t2.id)
        XCTAssertEqual(vm.queueTrackIDs, [t3.id])
        XCTAssertEqual(defaults.array(forKey: "playback.queueTrackIDs") as? [String], [t3.id.uuidString])

        vm.clearQueue()
        XCTAssertEqual(vm.queueTrackIDs, [])
        XCTAssertEqual(defaults.array(forKey: "playback.queueTrackIDs") as? [String], [])
    }

    func testQueueRestoreFromDefaults() async {
        let t1 = makeTrack(UUID(), title: "t1", no: 1)
        let t2 = makeTrack(UUID(), title: "t2", no: 2)
        let t3 = makeTrack(UUID(), title: "t3", no: 3)

        let suiteName = "test.queue.restore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set([t3.id.uuidString, t2.id.uuidString], forKey: "playback.queueTrackIDs")

        let vm = MainViewModel(
            libraryService: FakeLibraryService(tracks: [t1, t2, t3]),
            playlistService: FakePlaylistService(),
            historyService: FakeHistoryService(),
            audioEngine: FakeAudioEngine(),
            nowPlayingController: NowPlayingController(),
            defaults: defaults,
            enableRemoteCommands: false
        )

        await Task.yield()
        XCTAssertEqual(vm.queueTrackIDs, [t3.id, t2.id])
    }

    func testSpaceKeyPlaysSelectedTrackWhenDifferentFromCurrent() async {
        let t1 = makeTrack(UUID(), title: "t1", no: 1)
        let t2 = makeTrack(UUID(), title: "t2", no: 2)

        let suiteName = "test.space.selected.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let vm = MainViewModel(
            libraryService: FakeLibraryService(tracks: [t1, t2]),
            playlistService: FakePlaylistService(),
            historyService: FakeHistoryService(),
            audioEngine: FakeAudioEngine(),
            nowPlayingController: NowPlayingController(),
            defaults: defaults,
            enableRemoteCommands: false
        )

        await Task.yield()

        vm.selectedTrackID = t1.id
        vm.playSelected()
        for _ in 0..<8 { await Task.yield() }
        XCTAssertEqual(vm.playbackState.currentTrack?.id, t1.id)
        XCTAssertEqual(vm.playbackState.status, .playing)

        vm.selectedTrackID = t2.id
        XCTAssertEqual(vm.selectedTrack?.id, t2.id)
        vm.handleSpaceKeyToggle()
        for _ in 0..<8 { await Task.yield() }
        XCTAssertEqual(vm.playbackState.currentTrack?.id, t2.id)
        XCTAssertEqual(vm.playbackState.status, .playing)
        XCTAssertEqual(vm.queueTrackIDs, [t1.id])
    }
}

@MainActor
private final class FakeLibraryService: LibraryService {
    private let tracksSubject: CurrentValueSubject<[Track], Never>
    private let sourcesSubject = CurrentValueSubject<[ImportSource], Never>([])
    private let statusSubject = CurrentValueSubject<LibraryOperationStatus?, Never>(nil)

    init(tracks: [Track]) {
        self.tracksSubject = CurrentValueSubject<[Track], Never>(tracks)
    }

    func addImportSource(_ source: ImportSource) async throws {}
    func rescanAll() async {}
    func importFiles(_ urls: [URL]) async {}

    var tracksPublisher: AnyPublisher<[Track], Never> { tracksSubject.eraseToAnyPublisher() }
    var importSourcesPublisher: AnyPublisher<[ImportSource], Never> { sourcesSubject.eraseToAnyPublisher() }
    var operationStatusPublisher: AnyPublisher<LibraryOperationStatus?, Never> { statusSubject.eraseToAnyPublisher() }

    func currentTracks() -> [Track] { tracksSubject.value }
    func currentSources() -> [ImportSource] { [] }
}

@MainActor
private final class FakePlaylistService: PlaylistService {
    func createPlaylist(name: String) throws -> Playlist {
        Playlist(id: UUID(), name: name, createdAt: Date(), updatedAt: Date())
    }

    func renamePlaylist(id: UUID, name: String) throws {}
    func deletePlaylist(id: UUID) throws {}
    func addTrack(_ trackID: UUID, to playlistID: UUID) throws {}
    func removeTrack(_ trackID: UUID, from playlistID: UUID) throws {}
    func moveTrack(in playlistID: UUID, from sourceIndex: Int, to destinationIndex: Int) throws {}
    func playlists() -> [Playlist] { [] }
    func tracks(in playlistID: UUID) -> [Track] { [] }
}

@MainActor
private final class FakeHistoryService: HistoryService {
    func recordPlay(trackId: UUID, at: Date, playedSeconds: Double) {}
    func recent(limit: Int) -> [HistoryEntry] { [] }
    func clearHistory() {}
    func markFavorite(trackID: UUID, isFavorite: Bool) {}
    func favoriteTrackIDs() -> Set<UUID> { [] }
    func stats(for trackID: UUID) -> TrackStats? { nil }
}

@MainActor
private final class FakeAudioEngine: AudioEngine {
    private let subject = CurrentValueSubject<PlaybackState, Never>(PlaybackState())
    private var currentState = PlaybackState()

    func load(track: Track) async throws {
        currentState.currentTrack = track
        currentState.status = .paused
        currentState.duration = track.duration
        subject.send(currentState)
    }

    func play() {
        currentState.status = .playing
        subject.send(currentState)
    }

    func pause() {
        currentState.status = .paused
        subject.send(currentState)
    }

    func seek(to seconds: Double) {
        currentState.position = seconds
        subject.send(currentState)
    }

    func setVolume(_ value: Float) {
        currentState.volume = value
        subject.send(currentState)
    }

    func setReplayGain(enabled: Bool) {
        currentState.replayGainEnabled = enabled
        subject.send(currentState)
    }

    func setFade(duration: TimeInterval) {
        currentState.fadeDuration = duration
        subject.send(currentState)
    }

    var statePublisher: AnyPublisher<PlaybackState, Never> { subject.eraseToAnyPublisher() }
}
