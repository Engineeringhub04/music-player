# Music Player

A personal-use Flutter app for searching, streaming, and downloading YouTube
videos and audio — VidMate-style. It talks to a self-hosted **extractor
server** (yt-dlp based, built separately) for search, trending, formats, and
stream URLs.

Personal use only. Not for the Play Store. No Firebase, no push, no analytics.

## Server configuration

The app talks to the extractor server with an `X-API-Key` header on every
request.

| Setting | Source |
|---|---|
| Server base URL | `--dart-define=EXTRACTOR_BASE_URL` (default `http://127.0.0.1:8001`) |
| API key | `--dart-define=EXTRACTOR_API_KEY` (default built-in) |

Both can be changed at runtime in **Settings** (Library tab → gear icon) and
are persisted in SharedPreferences. Use **Test connection** to verify the
server is reachable (it calls `POST /trending`).

## Features

- **Home** — trending grid, pull-to-refresh
- **Search** — debounced live results, playlist/URL loader, built-in browser
- **Watch** — in-app player (chewie), quality selector, Download Video / MP3
- **Downloads** — background downloads (max 3 parallel), pause/resume/cancel,
  progress + speed, Wi-Fi-only option
- **Library** — downloaded files grid, in-app playback, rename/share/delete,
  storage usage; files live in the app-specific `MusicPlayer` folder
  (external storage on Android 10+, app documents on iOS)
- **Browser** — built-in web view; detects YouTube/direct video URLs and
  offers to fetch or download them
- **Playlist** — paste a playlist URL, tick videos, batch-download them
- **History** — watched / downloaded (JSON file, no database)
- **Share receiver** — share a link from any app into Music Player to open it
  with the download sheet

## Build (debug APK)

```bash
export PATH=$HOME/workspace/flutter-sdk/bin:$PATH
cd ~/workspace/music-player
flutter build apk --debug \
  --dart-define=EXTRACTOR_BASE_URL=http://YOUR_SERVER:8001 \
  --dart-define=EXTRACTOR_API_KEY=your-key
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

Notes:

- Do **not** run `sdkmanager` on this machine (broken behind the proxy).
- Some Flutter plugins declare AGP versions that can't be downloaded here;
  their `android/build.gradle[.kts]` files in the pub cache are pinned to the
  cached AGP 9.1.0. Re-apply after `flutter pub get` wipes the cache.
- The Gradle plugin-marker POMs for `com.android.application:9.1.0` and
  `org.jetbrains.kotlin.android:2.4.0` live in `~/workspace/maven-local`,
  referenced from `android/settings.gradle.kts`.

## Project layout

```
lib/
  main.dart            # bootstrap, theme switch, bottom-nav shell, share receiver
  theme.dart           # dark-first Material 3 theme, violet->pink gradient
  models/video_info.dart
  services/
    api_client.dart      # POST /search /trending /formats /stream /playlist + X-API-Key
    download_manager.dart# background_downloader wrapper (3 parallel, pause/resume/cancel)
    storage_service.dart # downloaded files: list/rename/share/delete
    history_service.dart # watched/downloaded history as JSON
    settings_service.dart# SharedPreferences: server URL, key, quality, wifi-only, theme
  screens/             # home, search, watch, downloads, library, browser,
                       # playlist, history, settings
  widgets/video_card.dart
```
