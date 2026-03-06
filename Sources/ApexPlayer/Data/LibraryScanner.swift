import Foundation

actor LibraryScanner {
    private let supportedExtensions: Set<String> = ["mp3", "m4a", "flac", "wav", "aiff", "aif"]
    private let maxConcurrentExtraction = 6

    func scan(url: URL, progress: (@MainActor @Sendable (Int, Int, URL) -> Void)? = nil) async -> [Track] {
        await scan(urls: [url], progress: progress)
    }

    func scan(urls: [URL], progress: (@MainActor @Sendable (Int, Int, URL) -> Void)? = nil) async -> [Track] {
        let fileURLs = collectAudioFiles(from: urls)
        let total = fileURLs.count
        guard total > 0 else { return [] }

        var nextIndex = 0
        var completed = 0
        var extracted: [(Int, Track)] = []

        await withTaskGroup(of: (Int, Track?).self) { group in
            let initialCount = min(maxConcurrentExtraction, total)
            for _ in 0..<initialCount {
                let index = nextIndex
                let fileURL = fileURLs[index]
                nextIndex += 1
                group.addTask {
                    let extractor = MetadataExtractor()
                    let track = try? await extractor.extract(from: fileURL)
                    return (index, track)
                }
            }

            while let (index, track) = await group.next() {
                completed += 1
                if let track {
                    extracted.append((index, track))
                }
                if let progress {
                    await progress(completed, total, fileURLs[index])
                }

                if nextIndex < total {
                    let newIndex = nextIndex
                    let fileURL = fileURLs[newIndex]
                    nextIndex += 1
                    group.addTask {
                        let extractor = MetadataExtractor()
                        let track = try? await extractor.extract(from: fileURL)
                        return (newIndex, track)
                    }
                }
            }
        }

        return extracted
            .sorted { $0.0 < $1.0 }
            .map(\.1)
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
