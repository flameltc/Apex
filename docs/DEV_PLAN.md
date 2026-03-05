# ApexPlayer 开发总文档（收尾版）

## 1. 项目目标与边界
- 目标：交付 macOS 本地音乐播放器内测版。
- 版本策略：A1（内测版）。
- 收尾范围：B1（稳定性 + 发布链路，不新增功能）。
- 发布方式：C2（本地签名 + DMG，不做 notarization）。
- 验收强度：D2（200 首真实曲库 + 30 分钟连续播放）。

## 2. 架构总览
- App 层：SwiftUI 生命周期与依赖注入。
- Domain 层：模型与协议定义，约束服务边界。
- Data 层：SQLite 持久化、曲库扫描、元数据抽取、目录监听。
- Playback 层：AVAudioEngine 播放链路、ReplayGain、淡入淡出。
- SystemIntegration 层：Now Playing 信息与媒体键控制。
- UI 层：资料库侧栏、列表详情区、底部控制栏、设置与内测操作入口。

## 3. 模块清单与职责
- `AppContainer`
- 组装 Repository/Service/Engine，注入到 ViewModel。
- `LibraryService`
- 导入目录/文件、全量重扫、扫描状态发布、曲库变更推送。
- `PlaylistService`
- 播放列表创建、重命名、删除、增删曲目、排序移动。
- `HistoryService`
- 最近播放记录、收藏状态、历史清理、统计信息读取。
- `AudioEngine`
- 载入、播放/暂停、Seek、音量控制、ReplayGain 开关、淡入淡出时长。
- `MainViewModel`
- 汇总 UI 状态、处理页面选择、播放控制、模式切换、恢复上次播放位置。

## 4. 数据结构（核心）
- `Track`
- 文件路径、格式、时长、采样率、码率、标签信息、ReplayGain 信息、可用性。
- `Playlist`
- 名称、创建/更新时间。
- `HistoryEntry`
- 曲目、播放时间、已播时长。
- `ReplayGainInfo`
- `trackGainDb` / `albumGainDb` / `peak`。
- `PlaybackState`
- 状态（playing/paused/stopped 等）、当前曲目、进度、音量、开关状态。
- `PlaybackMode`
- 顺序、随机、单曲循环。

## 5. 数据库表（SQLite）
- `tracks`
- `import_sources`
- `playlists`
- `playlist_items`
- `track_stats`
- `play_history`

## 6. 接口契约（关键协议）
- `AudioEngine`
- `load/play/pause/seek/setVolume/setReplayGain/setFade/statePublisher`
- `LibraryService`
- `addImportSource/rescanAll/importFiles/tracksPublisher/importSourcesPublisher/operationStatusPublisher`
- `PlaylistService`
- `create/rename/delete/add/remove/move/playlists/tracks(in:)`
- `HistoryService`
- `recordPlay/recent/clearHistory/markFavorite/favoriteTrackIDs/stats`

## 7. 关键流程
- 导入流程：OpenPanel 选目录或文件 -> 扫描 -> 元数据提取 -> upsert 数据库 -> UI 刷新。
- 扫描流程：发布结构化进度（文案 + 百分比）到顶部状态条。
- 播放流程：选曲 -> `load` -> `play` -> 进度更新 -> 播放结束后按模式自动下一首。
- 恢复流程：保存上次曲目 ID + 进度；启动后加载并 seek 到上次位置（暂停态）。

## 8. 非功能要求（内测版）
- 稳定性：连续播放 30 分钟不崩溃、无明显 UI 卡顿。
- 数据安全：收藏/播放列表/历史在重启后可读。
- 可观察性：导入/重扫有明确状态反馈。

## 9. 里程碑（收尾版）
- M1：稳定性修补（播放、扫描、恢复、边界错误）。
- M2：发布链路（release 构建、app bundle、DMG、签名）。
- M3：内测文档与验收报告。

## 10. 当前判定
- 已进入收尾阶段，适合进行小范围内测发放。
