import Foundation
import MediaPlayer

final class NowPlayingController {
    private var handlersInstalled = false

    func update(state: PlaybackState) {
        var info: [String: Any] = [:]
        if let track = state.currentTrack {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist
            info[MPMediaItemPropertyAlbumTitle] = track.album
            info[MPMediaItemPropertyPlaybackDuration] = state.duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.position
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.status == .playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func installRemoteCommands(onPlay: @escaping () -> Void, onPause: @escaping () -> Void, onNext: @escaping () -> Void, onPrevious: @escaping () -> Void) {
        guard !handlersInstalled else { return }
        handlersInstalled = true

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { _ in
            onNext()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { _ in
            onPrevious()
            return .success
        }
    }
}
