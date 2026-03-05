import AVFoundation
import Foundation

struct MetadataExtractor {
    func extract(from url: URL) async throws -> Track {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        let format = url.pathExtension.lowercased()
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

        let commonMetadata = try await asset.load(.commonMetadata)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var trackNo = 0
        var discNo = 0

        for item in commonMetadata {
            guard let key = item.commonKey?.rawValue else { continue }
            if key == AVMetadataKey.commonKeyTitle.rawValue {
                if let value = try? await item.load(.stringValue) {
                    title = value
                }
            }
            if key == AVMetadataKey.commonKeyArtist.rawValue {
                if let value = try? await item.load(.stringValue) {
                    artist = value
                }
            }
            if key == AVMetadataKey.commonKeyAlbumName.rawValue {
                if let value = try? await item.load(.stringValue) {
                    album = value
                }
            }
        }

        let metadata = try await asset.load(.metadata)
        let replayGain = await parseReplayGain(from: metadata)
        if let item = metadata.first(where: { $0.identifier?.rawValue.contains("trackNumber") == true }),
           let number = try? await item.load(.numberValue) {
            trackNo = number.intValue
        }
        if let item = metadata.first(where: { $0.identifier?.rawValue.contains("discNumber") == true }),
           let number = try? await item.load(.numberValue) {
            discNo = number.intValue
        }

        let bitRate = await estimateBitRate(asset: asset, duration: durationSeconds)
        let sampleRate = await estimateSampleRate(asset: asset)

        return Track(
            id: UUID(),
            filePath: url.path,
            bookmarkData: nil,
            mtime: mtime,
            duration: durationSeconds.isFinite ? durationSeconds : 0,
            sampleRate: sampleRate,
            bitRate: bitRate,
            format: format,
            title: title,
            artist: artist,
            album: album,
            trackNo: trackNo,
            discNo: discNo,
            coverArtPath: nil,
            replayGain: replayGain,
            isAvailable: true
        )
    }

    private func estimateBitRate(asset: AVURLAsset, duration: Double) async -> Int {
        guard duration > 0, let fileSize = try? asset.url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return 0
        }
        let bits = Double(fileSize) * 8
        return Int(bits / duration)
    }

    private func estimateSampleRate(asset: AVURLAsset) async -> Double {
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let formatDescriptions = try? await track.load(.formatDescriptions),
              let first = formatDescriptions.first,
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(first) else {
            return 0
        }
        return streamDescription.pointee.mSampleRate
    }

    private func parseReplayGain(from metadata: [AVMetadataItem]) async -> ReplayGainInfo {
        var trackDb: Double?
        var albumDb: Double?
        var peak: Double?

        for item in metadata {
            guard let identifier = item.identifier?.rawValue.lowercased() else { continue }
            let value = ((try? await item.load(.stringValue)) ?? "").lowercased()
            if identifier.contains("replaygain_track_gain") || identifier.contains("itunesnorm") {
                trackDb = parseDb(value)
            }
            if identifier.contains("replaygain_album_gain") {
                albumDb = parseDb(value)
            }
            if identifier.contains("replaygain_track_peak") || identifier.contains("replaygain_album_peak") {
                peak = Double(value.replacingOccurrences(of: "db", with: "").trimmingCharacters(in: .whitespaces))
            }
        }

        return ReplayGainInfo(trackGainDb: trackDb, albumGainDb: albumDb, peak: peak)
    }

    private func parseDb(_ value: String) -> Double? {
        let cleaned = value.replacingOccurrences(of: "db", with: "").replacingOccurrences(of: "+", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }
}
