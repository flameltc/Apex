import Foundation

@MainActor
struct LibraryScanner {
    private let supportedExtensions: Set<String> = ["mp3", "m4a", "flac", "wav", "aiff", "aif"]
    private let extractor = MetadataExtractor()

    func scan(url: URL, progress: ((Int, Int, URL) -> Void)? = nil) async -> [Track] {
        await scan(urls: [url], progress: progress)
    }

    func scan(urls: [URL], progress: ((Int, Int, URL) -> Void)? = nil) async -> [Track] {
        let fileURLs = collectAudioFiles(from: urls)
        let total = fileURLs.count

        var tracks: [Track] = []
        for (index, fileURL) in fileURLs.enumerated() {
            if let track = try? await extractor.extract(from: fileURL) {
                tracks.append(track)
            }
            progress?(index + 1, total, fileURL)
        }
        return tracks
    }

    private func collectAudioFiles(from urls: [URL]) -> [URL] {
        var all: [URL] = []
        for url in urls {
            all.append(contentsOf: collectAudioFiles(from: url))
        }
        return all
    }

    private func collectAudioFiles(from url: URL) -> [URL] {
        var urls: [URL] = []
        if url.hasDirectoryPath {
            let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            while let fileURL = enumerator?.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    urls.append(fileURL)
                }
            }
        } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
            urls.append(url)
        }
        return urls
    }
}
