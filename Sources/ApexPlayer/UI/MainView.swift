import AppKit
import SwiftUI

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @State private var keyboardShortcutController = KeyboardShortcutController()
    @State private var newPlaylistName = ""
    @State private var renamingPlaylist: Playlist?
    @State private var renameText = ""
    @State private var deletePlaylist: Playlist?
    @State private var didSetupShortcuts = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                detailContent
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .animation(AppTheme.Motion.normal, value: viewModel.selectedSection)
                    .animation(AppTheme.Motion.normal, value: viewModel.selectedPlaylist?.id)
                TransportBarView(viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .preferredColorScheme(viewModel.themeMode == .dark ? .dark : .light)
        .animation(AppTheme.Motion.quick, value: viewModel.playbackState.status)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            if !didSetupShortcuts {
                keyboardShortcutController.start {
                    viewModel.handleSpaceKeyToggle()
                }
                didSetupShortcuts = true
            }
        }
        .onDisappear {
            keyboardShortcutController.stop()
            didSetupShortcuts = false
        }
        .alert("错误", isPresented: Binding(
            get: { viewModel.currentError != nil },
            set: { _ in viewModel.currentError = nil }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.currentError ?? "")
        }
        .sheet(item: $renamingPlaylist) { playlist in
            VStack(spacing: 12) {
                Text("重命名播放列表")
                    .font(.headline)
                TextField("名称", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("取消") { renamingPlaylist = nil }
                    Spacer()
                    Button("保存") {
                        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        viewModel.renamePlaylist(id: playlist.id, name: name)
                        renamingPlaylist = nil
                    }
                }
            }
            .padding(16)
            .frame(width: 360)
        }
        .alert("删除播放列表", isPresented: Binding(
            get: { deletePlaylist != nil },
            set: { newValue in if !newValue { deletePlaylist = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let playlist = deletePlaylist {
                    viewModel.deletePlaylist(id: playlist.id)
                }
                deletePlaylist = nil
            }
            Button("取消", role: .cancel) { deletePlaylist = nil }
        } message: {
            Text("确定要删除该播放列表吗？该操作不可恢复。")
        }
    }

    private var sidebar: some View {
        List(selection: $viewModel.sidebarSelection) {
            Section("资料库") {
                ForEach([LibrarySection.allTracks, .artists, .albums, .recentlyPlayed, .favorites, .settings]) { section in
                    Label(section.rawValue, systemImage: icon(for: section))
                        .tag(MainViewModel.SidebarSelection.section(section))
                }
            }

            Section("播放列表") {
                ForEach(viewModel.playlists) { playlist in
                    Text(playlist.name)
                        .tag(MainViewModel.SidebarSelection.playlist(playlist.id))
                        .contextMenu {
                            Button("添加当前选中歌曲") { viewModel.addSelectedTrack(to: playlist) }
                            Button("重命名") {
                                renamingPlaylist = playlist
                                renameText = playlist.name
                            }
                            Button("删除", role: .destructive) { deletePlaylist = playlist }
                        }
                }

                HStack {
                    TextField("新播放列表", text: $newPlaylistName)
                    Button("创建") {
                        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        viewModel.createPlaylist(name: name)
                        newPlaylistName = ""
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    }

    private var topBar: some View {
        VStack(spacing: 6) {
            HStack {
                if viewModel.isArtistDrillDown {
                    Button("返回") { viewModel.backFromArtist() }
                } else if viewModel.isAlbumDrillDown {
                    Button("返回") { viewModel.backFromAlbum() }
                }
                Text(viewModel.detailTitle)
                    .font(.headline)
                if viewModel.isArtistDrillDown {
                    Text("· \(viewModel.artistDetailTitle)")
                        .foregroundStyle(.secondary)
                } else if viewModel.isAlbumDrillDown {
                    Text("· \(viewModel.albumDetailTitle)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.selectedSection != .settings {
                    TextField("搜索标题/艺术家/专辑", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
                Button("添加目录") { viewModel.addFolder() }
                Button("导入文件") { viewModel.importFiles() }
                Button("重扫") { viewModel.rescanAll() }
                    .disabled(viewModel.isLibraryBusy)
                if viewModel.selectedPlaylist != nil {
                    Button("移除选中(\(viewModel.selectedPlaylistTrackIDs.count))") {
                        viewModel.removeSelectedTracksFromCurrentPlaylist()
                    }
                    .disabled(viewModel.selectedPlaylistTrackIDs.isEmpty)
                }
                if viewModel.selectedSection == .recentlyPlayed {
                    Button("清空历史") { viewModel.clearHistory() }
                }
            }

            if let status = viewModel.libraryOperationStatus {
                HStack(spacing: 8) {
                    if viewModel.isLibraryBusy { ProgressView().scaleEffect(0.7) }
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if viewModel.isLibraryBusy, let progress = viewModel.libraryOperationProgress {
                        ProgressView(value: progress)
                            .frame(width: 140)
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .techCard()
    }

    @ViewBuilder
    private var detailContent: some View {
        if viewModel.isLibraryEmpty {
            emptyState
        } else if viewModel.selectedSection == .settings {
            settingsView
        } else if viewModel.selectedSection == .recentlyPlayed {
            recentTable
        } else if viewModel.selectedSection == .artists {
            if viewModel.isArtistDrillDown {
                artistTrackTable
            } else {
                artistTable
            }
        } else if viewModel.selectedSection == .albums {
            if viewModel.isAlbumDrillDown {
                albumTrackTable
            } else {
                albumTable
            }
        } else if viewModel.selectedPlaylist != nil {
            playlistList
        } else {
            trackTable
        }
    }

    private var playlistList: some View {
        List(selection: $viewModel.selectedPlaylistTrackIDs) {
            ForEach(viewModel.filteredTracks, id: \.id) { track in
                HStack(spacing: 8) {
                    Text(track.title)
                    Text(track.artist)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTime(track.duration))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .tag(track.id)
                .onTapGesture {
                    viewModel.selectedTrackID = track.id
                    viewModel.selectedPlaylistTrackIDs = [track.id]
                }
                .onTapGesture(count: 2) { viewModel.playTrack(track) }
            }
            .onMove(perform: viewModel.movePlaylistTrack)
        }
        .scrollContentBackground(.hidden)
        .techCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.house")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("欢迎使用 ApexPlayer")
                .font(.title3)
            Text("先添加音乐目录或导入文件，建立你的本地曲库。")
                .foregroundStyle(.secondary)
            HStack {
                Button("添加目录") { viewModel.addFolder() }
                Button("导入文件") { viewModel.importFiles() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trackTable: some View {
        VStack(spacing: 0) {
            Table(viewModel.filteredTracks, selection: $viewModel.selectedTrackID) {
                TableColumn("标题") { track in Text(track.title) }
                TableColumn("艺术家") { track in Text(track.artist) }
                TableColumn("专辑") { track in Text(track.album) }
                TableColumn("格式") { track in Text(track.format.uppercased()) }
                TableColumn("时长") { track in Text(formatTime(track.duration)) }
                TableColumn("收藏") { track in
                    Button {
                        viewModel.toggleFavorite(track.id)
                    } label: {
                        Image(systemName: viewModel.favorites.contains(track.id) ? "heart.fill" : "heart")
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.01))
            .contextMenu {
                Button("播放") { viewModel.playSelected() }
                if viewModel.selectedPlaylist != nil {
                    Button("从当前播放列表移除") { viewModel.removeSelectedTrackFromCurrentPlaylist() }
                }
            }
            .onDoubleClick {
                viewModel.playSelected()
            }
        }
        .techCard()
    }

    private var recentTable: some View {
        List {
            ForEach(viewModel.recentSections) { section in
                Section(sectionHeader(section.date)) {
                    ForEach(section.rows) { row in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(row.track.title)
                                Text(row.track.artist)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            Text(formatTime(row.entry.playedSeconds))
                                .foregroundStyle(.secondary)
                            Text(row.entry.playedAt, style: .time)
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .techCard()
    }

    private var artistTable: some View {
        List(viewModel.artistSummaries) { artist in
            Button {
                viewModel.openArtist(artist.name)
            } label: {
                HStack {
                    Text(artist.name)
                    Spacer()
                    Text("\(artist.trackCount)")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .scrollContentBackground(.hidden)
        .techCard()
    }

    private var albumTable: some View {
        List(viewModel.albumSummaries) { album in
            Button {
                viewModel.openAlbum(album.id)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(album.title)
                        Text(album.artist)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    Spacer()
                    Text("\(album.trackCount)")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .scrollContentBackground(.hidden)
        .techCard()
    }

    private var artistTrackTable: some View {
        List {
            ForEach(viewModel.artistTrackGroups) { group in
                Section(group.title) {
                    ForEach(group.tracks) { track in
                        HStack {
                            Text("\(track.trackNo).")
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .trailing)
                            Text(track.title)
                            Spacer()
                            Text(formatTime(track.duration))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.selectedTrackID = track.id }
                        .onTapGesture(count: 2) { viewModel.playTrack(track) }
                        .contextMenu {
                            Button("播放") { viewModel.playTrack(track) }
                            Button(viewModel.isFavorite(track.id) ? "取消收藏" : "收藏") {
                                viewModel.toggleFavorite(track.id)
                            }
                            Menu("加入播放列表") {
                                ForEach(viewModel.playlists) { playlist in
                                    Button(playlist.name) { viewModel.addTrack(track.id, to: playlist) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .techCard()
    }

    private var albumTrackTable: some View {
        List {
            ForEach(viewModel.albumTrackGroups) { group in
                Section(group.title) {
                    ForEach(group.tracks) { track in
                        HStack {
                            Text("\(track.trackNo).")
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .trailing)
                            Text(track.title)
                            Spacer()
                            Text(formatTime(track.duration))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.selectedTrackID = track.id }
                        .onTapGesture(count: 2) { viewModel.playTrack(track) }
                        .contextMenu {
                            Button("播放") { viewModel.playTrack(track) }
                            Button(viewModel.isFavorite(track.id) ? "取消收藏" : "收藏") {
                                viewModel.toggleFavorite(track.id)
                            }
                            Menu("加入播放列表") {
                                ForEach(viewModel.playlists) { playlist in
                                    Button(playlist.name) { viewModel.addTrack(track.id, to: playlist) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .techCard()
    }

    private var settingsView: some View {
        Form {
            Picker("主题", selection: Binding(
                get: { viewModel.themeMode },
                set: { viewModel.setThemeMode($0) }
            )) {
                ForEach(MainViewModel.ThemeMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("启用 ReplayGain", isOn: Binding(
                get: { viewModel.isReplayingGainEnabled },
                set: { viewModel.setReplayGainEnabled($0) }
            ))
            HStack {
                Text("淡入淡出时长")
                Slider(value: Binding(
                    get: { viewModel.fadeDurationMs },
                    set: { viewModel.setFadeDuration(ms: $0) }
                ), in: 0...1000, step: 50)
                Text("\(Int(viewModel.fadeDurationMs))ms")
                    .foregroundStyle(.secondary)
            }
            Text("设置会自动保存，并在下次启动时恢复。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .techCard()
    }

    private func icon(for section: LibrarySection) -> String {
        switch section {
        case .allTracks: return "music.note.list"
        case .artists: return "music.mic"
        case .albums: return "square.stack"
        case .recentlyPlayed: return "clock"
        case .favorites: return "heart"
        case .settings: return "gearshape"
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "--:--" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func sectionHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct DoubleClickModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onTapGesture(count: 2, perform: action)
    }
}

private extension View {
    func onDoubleClick(_ action: @escaping () -> Void) -> some View {
        modifier(DoubleClickModifier(action: action))
    }
}
