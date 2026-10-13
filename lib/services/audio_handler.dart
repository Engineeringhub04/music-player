import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

/// Background-capable audio engine: just_audio wrapped in an audio_service
/// handler. Produces the system media notification (play/pause/next/prev)
/// and keeps playing when the app is backgrounded, on Android and iOS.
///
/// Video rendering (watch screen) stays on video_player; this handler is
/// the SOLE audio engine for music playback.
class MusicAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  /// Direct access for position/duration streams.
  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  MusicAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  /// Load [url] (network stream or local file path) and start playback.
  Future<void> playUrl(String url, MediaItem item) async {
    // Android 13+: the media notification needs POST_NOTIFICATIONS.
    // Without it, background audio plays but no control panel appears.
    if (Platform.isAndroid) {
      try {
        await Permission.notification.request();
      } catch (_) {}
    }
    mediaItem.add(item);
    final source = url.startsWith('http')
        ? AudioSource.uri(Uri.parse(url))
        : AudioSource.uri(Uri.file(url));
    await _player.setAudioSource(source);
    await _player.play();
  }

  @override
  Future<void> play() {
    if (_external) return onExternalPlay?.call() ?? Future.value();
    return _player.play();
  }

  @override
  Future<void> pause() {
    if (_external) return onExternalPause?.call() ?? Future.value();
    return _player.pause();
  }

  @override
  Future<void> seek(Duration position) {
    if (_external) {
      final cb = onExternalSeek;
      if (cb != null) return cb(position);
      return Future.value();
    }
    return _player.seek(position);
  }

  // ---------- External engine mode ----------
  // When video_player owns foreground playback (Player tab), the media
  // notification is driven manually and transport keys delegate to it.

  bool _external = false;
  Future<void> Function()? onExternalPlay;
  Future<void> Function()? onExternalPause;
  Future<void> Function(Duration)? onExternalSeek;
  Future<void> Function()? onExternalNext;
  Future<void> Function()? onExternalPrevious;

  bool get externalMode => _external;

  /// Enter external mode: transport controls delegate to the video engine.
  void enterExternalMode({
    required MediaItem item,
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
    Future<void> Function(Duration)? onSeek,
    Future<void> Function()? onNext,
    Future<void> Function()? onPrevious,
  }) {
    _external = true;
    onExternalPlay = onPlay;
    onExternalPause = onPause;
    onExternalSeek = onSeek;
    onExternalNext = onNext;
    onExternalPrevious = onPrevious;
    mediaItem.add(item);
    _pushExternal(playing: false, position: Duration.zero);
  }

  /// Push video-engine state into the notification.
  void pushExternalState({
    required bool playing,
    required Duration position,
    Duration? duration,
  }) {
    if (!_external) return;
    if (duration != null && duration > Duration.zero) {
      final cur = mediaItem.value;
      if (cur != null && cur.duration != duration) {
        mediaItem.add(cur.copyWith(duration: duration));
      }
    }
    _pushExternal(playing: playing, position: position);
  }

  void _pushExternal({
    required bool playing,
    required Duration position,
  }) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: AudioProcessingState.ready,
      playing: playing,
      updatePosition: position,
    ));
  }

  /// Leave external mode: just_audio events drive the notification again.
  void exitExternalMode() {
    _external = false;
    onExternalPlay = null;
    onExternalPause = null;
    onExternalSeek = null;
    onExternalNext = null;
    onExternalPrevious = null;
  }

  @override
  Future<void> skipToNext() {
    if (_external) return onExternalNext?.call() ?? Future.value();
    return Future.value();
  }

  @override
  Future<void> skipToPrevious() {
    if (_external) return onExternalPrevious?.call() ?? Future.value();
    return Future.value();
  }

  @override
  Future<void> stop() async {
    if (_external) {
      await onExternalPause?.call();
      return;
    }
    await _player.stop();
    await super.stop();
  }

  Future<void> dispose() => _player.dispose();
}
