import AVFoundation
import Combine
import Foundation

@MainActor
final class AVAudioEnginePlayer: AudioEngine {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var state = PlaybackState()
    private let stateSubject = CurrentValueSubject<PlaybackState, Never>(PlaybackState())
    private var progressTimer: Timer?

    private var gainNode = AVAudioMixerNode()
    private var currentFramePosition: AVAudioFramePosition = 0
    private var effectiveOutputVolume: Float = 1
    private var suppressedCompletionCallbacks = 0

    var statePublisher: AnyPublisher<PlaybackState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    init() {
        engine.attach(playerNode)
        engine.attach(gainNode)
        engine.connect(playerNode, to: gainNode, format: nil)
        engine.connect(gainNode, to: engine.mainMixerNode, format: nil)
        try? engine.start()
    }

    func load(track: Track) async throws {
        stopProgressTimer()
        stopAndSuppressCompletion()
        state.status = .loading
        state.currentTrack = track
        publish()

        let file = try AVAudioFile(forReading: track.fileURL)
        audioFile = file
        currentFramePosition = 0
        state.duration = track.duration
        scheduleFile(fromSeconds: 0)
        applyReplayGain()

        state.status = .paused
        state.position = 0
        publish()
    }

    func play() {
        guard audioFile != nil else { return }
        withFade(isIn: true) {
            self.playerNode.play()
            self.state.status = .playing
            self.publish()
            self.startProgressTimer()
        }
    }

    func pause() {
        withFade(isIn: false) {
            self.playerNode.pause()
            self.state.status = .paused
            self.publish()
            self.stopProgressTimer()
        }
    }

    func seek(to seconds: Double) {
        guard audioFile != nil else { return }
        let wasPlaying = state.status == .playing
        let target = max(0, min(seconds, state.duration))
        stopAndSuppressCompletion()
        scheduleFile(fromSeconds: target)
        state.position = target
        publish()
        if wasPlaying {
            playerNode.play()
        }
    }

    func setVolume(_ value: Float) {
        state.volume = value
        applyReplayGain()
        publish()
    }

    func setReplayGain(enabled: Bool) {
        state.replayGainEnabled = enabled
        applyReplayGain()
        publish()
    }

    func setFade(duration: TimeInterval) {
        state.fadeDuration = max(0, duration)
        publish()
    }

    private func scheduleFile(fromSeconds seconds: Double) {
        guard let file = audioFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, seconds) * sampleRate)
        let frameCount = AVAudioFrameCount(max(0, file.length - startFrame))
        currentFramePosition = startFrame

        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    if let self, self.suppressedCompletionCallbacks > 0 {
                        self.suppressedCompletionCallbacks -= 1
                        return
                    }
                    self?.state.status = .stopped
                    self?.state.position = self?.state.duration ?? 0
                    self?.publish()
                    self?.stopProgressTimer()
                }
            }
        )
    }

    private func stopAndSuppressCompletion() {
        suppressedCompletionCallbacks += 1
        playerNode.stop()
    }

    private func applyReplayGain() {
        let baseVolume = state.volume
        let multiplier: Double
        if state.replayGainEnabled, let info = state.currentTrack?.replayGain {
            multiplier = ReplayGain.effectiveGain(info: info)
        } else {
            multiplier = 1
        }
        effectiveOutputVolume = Float(Double(baseVolume) * multiplier)
        gainNode.outputVolume = effectiveOutputVolume
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      let nodeTime = self.playerNode.lastRenderTime,
                      let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime),
                      let file = self.audioFile else { return }

                let frame = self.currentFramePosition + AVAudioFramePosition(playerTime.sampleTime)
                let seconds = Double(frame) / file.processingFormat.sampleRate
                self.state.position = min(seconds, self.state.duration)
                self.publish()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func withFade(isIn: Bool, action: @escaping () -> Void) {
        let duration = state.fadeDuration
        guard duration > 0 else {
            action()
            return
        }

        let startVolume = gainNode.outputVolume
        let target = isIn ? effectiveOutputVolume : 0
        if isIn { gainNode.outputVolume = 0 }
        action()

        let steps = 10
        let interval = duration / Double(steps)
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let progress = Float(step) / Float(steps)
                    if isIn {
                        self.gainNode.outputVolume = target * progress
                    } else {
                        self.gainNode.outputVolume = startVolume * (1 - progress)
                    }
                }
            }
        }
    }

    private func publish() {
        stateSubject.send(state)
    }
}
