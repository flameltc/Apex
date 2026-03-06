import Combine
import Foundation

@MainActor
final class LibraryServiceImpl: LibraryService {
    private let trackRepository: TrackRepository
    private let sourceRepository: ImportSourceRepository
    private let scanner = LibraryScanner()
    private let watcher = DirectoryWatcher()
    private var debounceTask: Task<Void, Never>?

    private let tracksSubject = CurrentValueSubject<[Track], Never>([])
    private let sourcesSubject = CurrentValueSubject<[ImportSource], Never>([])
    private let operationStatusSubject = CurrentValueSubject<LibraryOperationStatus?, Never>(nil)

    var tracksPublisher: AnyPublisher<[Track], Never> { tracksSubject.eraseToAnyPublisher() }
    var importSourcesPublisher: AnyPublisher<[ImportSource], Never> { sourcesSubject.eraseToAnyPublisher() }
    var operationStatusPublisher: AnyPublisher<LibraryOperationStatus?, Never> { operationStatusSubject.eraseToAnyPublisher() }

    init(trackRepository: TrackRepository, sourceRepository: ImportSourceRepository) {
        self.trackRepository = trackRepository
        self.sourceRepository = sourceRepository
        loadInitialData()
        watcher.onChange = { [weak self] in
            guard let self else { return }
            self.scheduleRescan()
        }
    }

    func addImportSource(_ source: ImportSource) async throws {
        try sourceRepository.insert(source)
        var sources = (try? sourceRepository.fetchAll()) ?? []
        if !sources.contains(where: { $0.path == source.path }) {
            sources.insert(source, at: 0)
        }
        sourcesSubject.send(sources)
        updateWatcherPaths(sources)

        operationStatusSubject.send(LibraryOperationStatus(isRunning: true, message: "正在扫描目录...", progress: nil))
        let tracks = await scanner.scan(url: source.url) { [weak self] done, total, fileURL in
            self?.publishProgress(prefix: "正在扫描目录", done: done, total: total, current: fileURL.lastPathComponent)
        }
        try? trackRepository.upsertTracks(tracks)
        refreshTracks()
        publishCompleted("目录扫描完成")
    }

    func rescanAll() async {
        let sources = sourcesSubject.value
        let urls = sources.map(\.url)
        operationStatusSubject.send(LibraryOperationStatus(isRunning: true, message: "正在重扫曲库...", progress: nil))
        let tracks = await scanner.scan(urls: urls) { [weak self] done, total, fileURL in
            self?.publishProgress(prefix: "正在重扫曲库", done: done, total: total, current: fileURL.lastPathComponent)
        }
        try? trackRepository.upsertTracks(tracks)
        try? trackRepository.clearUnavailableTracks(matching: Set(tracks.map(\.filePath)))
        refreshTracks()
        publishCompleted("重扫完成")
    }

    func importFiles(_ urls: [URL]) async {
        operationStatusSubject.send(LibraryOperationStatus(isRunning: true, message: "正在导入文件...", progress: nil))
        let tracks = await scanner.scan(urls: urls) { [weak self] done, total, fileURL in
            self?.publishProgress(prefix: "正在导入文件", done: done, total: total, current: fileURL.lastPathComponent)
        }
        try? trackRepository.upsertTracks(tracks)
        refreshTracks()
        publishCompleted("导入完成")
    }

    func currentTracks() -> [Track] {
        tracksSubject.value
    }

    func currentSources() -> [ImportSource] {
        sourcesSubject.value
    }

    private func scheduleRescan() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await self?.rescanAll()
        }
    }

    private func loadInitialData() {
        let tracks = (try? trackRepository.fetchTracks()) ?? []
        tracksSubject.send(tracks)

        let sources = (try? sourceRepository.fetchAll()) ?? []
        sourcesSubject.send(sources)
        updateWatcherPaths(sources)
    }

    private func refreshTracks() {
        let tracks = (try? trackRepository.fetchTracks()) ?? []
        tracksSubject.send(tracks)
    }

    private func publishProgress(prefix: String, done: Int, total: Int, current: String) {
        guard total > 0 else {
            operationStatusSubject.send(LibraryOperationStatus(isRunning: true, message: "\(prefix)...", progress: nil))
            return
        }
        let ratio = Double(done) / Double(total)
        let percent = Int(ratio * 100)
        operationStatusSubject.send(
            LibraryOperationStatus(
                isRunning: true,
                message: "\(prefix) \(percent)% (\(done)/\(total)) · \(current)",
                progress: ratio
            )
        )
    }

    private func publishCompleted(_ message: String) {
        operationStatusSubject.send(LibraryOperationStatus(isRunning: false, message: message, progress: 1.0))
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self?.operationStatusSubject.send(nil) }
        }
    }

    private func updateWatcherPaths(_ sources: [ImportSource]) {
        let paths = sources.filter { $0.watchEnabled && $0.type == .folder }.map(\.path)
        watcher.start(paths: paths)
    }
}
