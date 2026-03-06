import SwiftUI

struct TransportBarView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(viewModel.playbackState.currentTrack?.title ?? "未播放")
                        .font(.headline)
                    Text(viewModel.playbackState.currentTrack?.artist ?? "")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Spacer()
                Button(action: viewModel.playPrevious) {
                    Image(systemName: "backward.fill")
                }
                Button(action: viewModel.togglePlayPause) {
                    Image(systemName: viewModel.playbackState.status == .playing ? "pause.fill" : "play.fill")
                }
                Button(action: viewModel.playNext) {
                    Image(systemName: "forward.fill")
                }
                .padding(.leading, 4)

                Slider(
                    value: Binding(
                        get: { viewModel.playbackState.volume },
                        set: { viewModel.setVolume($0) }
                    ),
                    in: 0...1
                )
                .frame(width: 130)
            }

            HStack {
                Text(formatTime(viewModel.playbackState.position))
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { min(viewModel.playbackState.position, viewModel.playbackState.duration) },
                        set: { viewModel.seek($0) }
                    ),
                    in: 0...max(viewModel.playbackState.duration, 1)
                )
                Text(formatTime(viewModel.playbackState.duration))
                    .font(.caption)

                Toggle("ReplayGain", isOn: Binding(
                    get: { viewModel.isReplayingGainEnabled },
                    set: { viewModel.setReplayGainEnabled($0) }
                ))
                .toggleStyle(.switch)

                HStack {
                    Text("淡入淡出")
                    Slider(
                        value: Binding(
                            get: { viewModel.fadeDurationMs },
                            set: { viewModel.setFadeDuration(ms: $0) }
                        ),
                        in: 0...1000,
                        step: 50
                    )
                    .frame(width: 120)
                    Text("\(Int(viewModel.fadeDurationMs))ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("模式", selection: Binding(
                    get: { viewModel.playbackMode },
                    set: { viewModel.setPlaybackMode($0) }
                )) {
                    ForEach(PlaybackMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Button("队列") { viewModel.isQueuePresented.toggle() }
                    .popover(isPresented: $viewModel.isQueuePresented) {
                        queuePopover
                    }
            }
        }
        .padding(12)
    }

    private var queuePopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("播放队列")
                .font(.headline)
            if let current = viewModel.queueCurrentTrack {
                HStack {
                    Text("当前")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(current.title)
                    Spacer()
                    Text(current.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if viewModel.queueUpNextTracks.isEmpty {
                Text("队列为空")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                HStack {
                    Text("即将播放")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("清空队列") { viewModel.clearQueue() }
                        .font(.caption)
                }
                List {
                    ForEach(viewModel.queueUpNextTracks.prefix(30), id: \.id) { track in
                        HStack {
                            Button {
                                viewModel.playFromQueue(track)
                                viewModel.isQueuePresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(track.title)
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(formatTime(track.duration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.removeQueueTrack(track.id)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onMove(perform: viewModel.moveQueueTrack)
                }
                .frame(height: 260)
            }
        }
        .padding(12)
        .frame(width: 420)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let value = Int(seconds)
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
