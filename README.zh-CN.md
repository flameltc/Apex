# ApexPlayer

[English](README.md) | 简体中文

一个基于 SwiftUI + AVFoundation 的 macOS 本地音乐播放器。

## 功能

- 本地音频播放（`mp3`, `m4a`, `flac`, `wav`, `aiff`）
- 支持目录自动扫描与手动导入文件
- 使用 SQLite 持久化曲库、播放列表、收藏和历史
- 播放列表详情页支持拖拽排序
- 支持“即将播放”队列面板（重排、移除、持久化）
- 最近播放页面
- 艺术家/专辑下钻，并按分组展示曲目
- ReplayGain 音量标准化（优先 track）
- 淡入淡出播放过渡
- 系统媒体键与 Now Playing 集成
- 后台并发扫描并实时更新进度

## 架构

- `App`：应用启动与依赖注入容器
- `Domain`：模型与服务协议
- `Data`：SQLite 仓储、元数据提取、扫描与目录监听
- `Playback`：`AVAudioEngine` 播放实现
- `SystemIntegration`：Now Playing 与远程命令
- `UI`：侧栏、列表详情、底部控制栏

## 运行

1. 确认已接受 Xcode 协议：
   - `sudo xcodebuild -license`
2. 编译并运行测试：
   - `swift test`
3. 在 Xcode 中打开本项目目录运行。

## 打包

- 构建 app bundle：`scripts/build_app_bundle.sh`
- 构建 DMG：`scripts/build_dmg.sh`
- 完整发布检查（测试 + 构建 + DMG + 校验和）：`scripts/release_check.sh`
