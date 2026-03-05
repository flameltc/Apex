# ApexPlayer

A local macOS music player built with SwiftUI + AVFoundation.

## Features

- Local file playback (`mp3`, `m4a`, `flac`, `wav`, `aiff`)
- Folder auto scan + manual file import
- SQLite persistence for library, playlists, favorites, and history
- Playlist detail page with drag-to-reorder support
- Recently played page
- ReplayGain volume normalization (track-first fallback)
- Fade-in/fade-out playback transitions
- Media key / Now Playing integration

## Architecture

- `App`: startup and dependency container
- `Domain`: models and service protocols
- `Data`: SQLite repositories, metadata extraction, scanning, directory watch
- `Playback`: `AVAudioEngine` implementation
- `SystemIntegration`: Now Playing and remote commands
- `UI`: sidebar, track table, transport controls

## Run

1. Ensure Xcode license is accepted:
   - `sudo xcodebuild -license`
2. Build and run tests:
   - `swift test`
3. Launch in Xcode by opening this package folder.

## Packaging

- Build app bundle: `scripts/build_app_bundle.sh`
- Build DMG: `scripts/build_dmg.sh`
