import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../models/video_info.dart';
import 'api_client.dart';
import 'audio_handler.dart';
import 'settings_service.dart';

/// Global playback state with queue support.
///
/// Two engines, one active at a time:
/// - VIDEO mode (Player tab visible, app foregrounded, video format
///   available): video_player renders the real video with sound.
/// - AUDIO mode (anywhere else): [MusicAudioHandler] (just_audio via
///   audio_service) plays audio — background-capable with a media
///   notification on Android/iOS.
///
/// Switching tabs or backgrounding the app hands playback between engines
/// at the current position. The notification stays correct in both modes.
class PlayerService extends ChangeNotifier with WidgetsBindingObserver {
  final SettingsService settings;
  final MusicAudioHandler audioHandler;

  PlayerService({required this.settings, required this.audioHandler}) {
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  final List<VideoInfo> _queue = [];
  int _index = -1;
  bool _loading = false;
  String? _error;
  bool _shuffle = false;
  bool _repeatOne = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  // Engine state.
  bool _playerTabVisible = false;
  bool _appBackgrounded = false;
  bool _videoMode = false;
  bool _videoLoading = false;
  VideoPlayerController? _videoController;
  String? _audioUrl;
  String? _videoUrl;
  bool _advancing = false;

  final List<StreamSubscription> _subs = [];

  List<VideoInfo> get queue => List.unmodifiable(_queue);
  int get currentIndex => _index;
  VideoInfo? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  bool get loading => _loading;
  String? get error => _error;
  bool get isPlaying => _playing;
  bool get shuffle => _shuffle;
  bool get repeatOne => _repeatOne;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get hasPrevious => _queue.length > 1;
  bool get hasNext => _queue.length > 1;

  /// Video engine state for the Player tab UI.
  bool get videoMode => _videoMode;
  bool get videoLoading => _videoLoading;
  VideoPlayerController? get videoController => _videoController;

  /// Next track in the queue (for the "Next:" line), or null.
  VideoInfo? get nextTrack => _queue.length > 1
      ? _queue[(_index + 1) % _queue.length]
      : null;

  void _listen() {
    _subs.add(audioHandler.playingStream.listen((playing) {
      if (_videoMode) return;
      if (playing != _playing) {
        _playing = playing;
        notifyListeners();
      }
    }));
    _subs.add(audioHandler.positionStream.listen((pos) {
      if (_videoMode) return;
      if (pos != _position) {
        _position = pos;
        notifyListeners();
      }
    }));
    _subs.add(audioHandler.durationStream.listen((dur) {
      if (_videoMode) return;
      final d = dur ?? Duration.zero;
      if (d != _duration) {
        _duration = d;
        notifyListeners();
      }
    }));
    _subs.add(audioHandler.processingStateStream.listen((state) {
      if (_videoMode) return;
      // Auto-advance when the track finishes.
      if (state == ProcessingState.completed &&
          _queue.length > 1 &&
          !_advancing) {
        _advancing = true;
        if (_repeatOne) {
          audioHandler.seek(Duration.zero);
          audioHandler.play();
          _advancing = false;
        } else {
          next(auto: true).whenComplete(() => _advancing = false);
        }
      }
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_appBackgrounded) {
        _appBackgrounded = true;
        _applyEngine();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_appBackgrounded) {
        _appBackgrounded = false;
        _applyEngine();
      }
    }
  }

  /// Called by the shell when the Player tab becomes visible/hidden.
  Future<void> setPlayerTabVisible(bool visible) async {
    if (_playerTabVisible == visible) return;
    _playerTabVisible = visible;
    await _applyEngine();
  }

  bool get _wantVideo =>
      _playerTabVisible &&
      !_appBackgrounded &&
      current != null &&
      _videoUrl != null;

  /// Play [video], optionally replacing the queue with [queue].
  Future<void> play(VideoInfo video, {List<VideoInfo>? queue}) async {
    if (queue != null) {
      _queue
        ..clear()
        ..addAll(queue);
      _index = _queue.indexWhere((v) => v.id == video.id && v.id.isNotEmpty);
      if (_index < 0) {
        _queue.insert(0, video);
        _index = 0;
      }
    } else {
      final existing =
          _queue.indexWhere((v) => v.id == video.id && v.id.isNotEmpty);
      if (existing >= 0) {
        _index = existing;
      } else {
        _queue.insert(0, video);
        if (_queue.length > 200) _queue.removeLast();
        _index = 0;
      }
    }
    notifyListeners();
    await _playCurrent();
  }

  /// Replace the whole queue and start at [startIndex].
  Future<void> playQueue(List<VideoInfo> videos, {int startIndex = 0}) async {
    if (videos.isEmpty) return;
    _queue
      ..clear()
      ..addAll(videos);
    _index = startIndex.clamp(0, videos.length - 1);
    notifyListeners();
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final video = current;
    if (video == null) return;
    _loading = true;
    _error = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _audioUrl = null;
    _videoUrl = null;
    _videoMode = false;
    _advancing = false;
    audioHandler.exitExternalMode();
    await _disposeVideoController();
    notifyListeners();
    try {
      if (video.isLocal) {
        _audioUrl = video.videoUrl;
        if (_isVideoFile(video.videoUrl)) _videoUrl = video.videoUrl;
      } else {
        final formats = await settings.apiClient.formats(video.videoUrl);
        final audio = _pickAudioFormat(formats) ??
            (formats.isNotEmpty ? formats.first : null);
        if (audio == null) {
          throw const ApiException('No playable formats found.');
        }
        _audioUrl = audio.directUrl ??
            await settings.apiClient.streamUrl(video.videoUrl, audio.formatId);
        // Resolve the video URL lazily only if the Player tab may show it.
        if (_playerTabVisible && !_appBackgrounded) {
          await _ensureVideoUrl(video, formats);
        }
      }
      _loading = false;
      notifyListeners();
      await _applyEngine();
    } on ApiException catch (e) {
      _loading = false;
      _error = e.message;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = 'Could not play: $e';
      notifyListeners();
    }
  }

  /// Resolve (and cache) a progressive video URL for [video].
  Future<void> _ensureVideoUrl(
      VideoInfo video, List<MediaFormat> formats) async {
    if (_videoUrl != null) return;
    try {
      final vf = _pickVideoFormat(formats);
      if (vf == null) {
        debugPrint('No progressive video format found for ${video.id}');
        return;
      }
      final url = vf.directUrl ??
          await settings.apiClient.streamUrl(video.videoUrl, vf.formatId);
      // Guard against track changes during the fetch.
      if (current?.id == video.id || current?.videoUrl == video.videoUrl) {
        _videoUrl = url;
      }
    } catch (e) {
      debugPrint('Video URL resolution failed for ${video.id}: $e');
    }
  }

  Future<void> _applyEngine() async {
    final video = current;
    if (video == null || _audioUrl == null) return;
    if (_playerTabVisible && !_appBackgrounded && _videoUrl == null) {
      // Player tab wants video: resolve the URL first.
      if (video.isLocal) {
        if (_isVideoFile(video.videoUrl)) _videoUrl = video.videoUrl;
      } else {
        try {
          final formats = await settings.apiClient.formats(video.videoUrl);
          await _ensureVideoUrl(video, formats);
        } catch (_) {}
        if (current != video) return; // track changed mid-fetch
      }
    }
    if (_wantVideo && !_videoMode) {
      await _enterVideoMode();
    } else if (!_wantVideo && _videoMode) {
      await _enterAudioMode();
    } else if (!_wantVideo && !_videoMode && !_playing && _error == null) {
      // Audio engine should be running but isn't (e.g. after a failed
      // video attempt or fresh start with no autoplay yet — only start
      // when we have a current track and were already playing).
      if (_position == Duration.zero && _audioUrl != null) {
        // Fresh track that never started (e.g. video failed): start audio.
        await _enterAudioMode();
      }
    } else if (_wantVideo && _videoMode && _videoController == null) {
      await _enterVideoMode();
    }
  }

  Future<void> _enterVideoMode() async {
    final url = _videoUrl;
    final video = current;
    if (url == null || video == null) {
      await _enterAudioMode();
      return;
    }
    _videoMode = true;
    _videoLoading = true;
    notifyListeners();
    // Stop the audio engine to avoid overlap.
    try {
      await audioHandler.player.pause();
    } catch (_) {}
    audioHandler.enterExternalMode(
      item: _mediaItemFor(video),
      onPlay: () async => _videoController?.play(),
      onPause: () async => _videoController?.pause(),
      onSeek: (p) async => _videoController?.seekTo(p),
      onNext: () => next(),
      onPrevious: () => previous(),
    );
    final from = _position;
    await _disposeVideoController();
    try {
      final c = video.isLocal
          ? VideoPlayerController.file(File(url))
          : VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController = c;
      c.addListener(_onVideoTick);
      await c.initialize();
      if (current != video) return; // track changed mid-init
      if (from > Duration.zero) await c.seekTo(from);
      await c.play();
    } catch (_) {
      // Video failed: fall back to audio-only.
      _videoMode = false;
      _videoUrl = null;
      audioHandler.exitExternalMode();
      await _disposeVideoController();
      _videoLoading = false;
      notifyListeners();
      await _enterAudioMode(from: _position);
      return;
    }
    _videoLoading = false;
    notifyListeners();
  }

  Future<void> _enterAudioMode({Duration? from}) async {
    _videoMode = false;
    _videoLoading = false;
    audioHandler.exitExternalMode();
    await _disposeVideoController();
    final url = _audioUrl;
    final video = current;
    if (url == null || video == null) {
      notifyListeners();
      return;
    }
    notifyListeners();
    try {
      await audioHandler.playUrl(url, _mediaItemFor(video));
      final p = from ?? _position;
      if (p > const Duration(seconds: 1)) {
        await audioHandler.seek(p);
      }
    } catch (e) {
      _error = 'Could not play: $e';
      notifyListeners();
    }
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final dur = c.value.duration;
    final playing = c.value.isPlaying;
    var changed = false;
    if (pos != _position) {
      _position = pos;
      changed = true;
    }
    if (dur > Duration.zero && dur != _duration) {
      _duration = dur;
      changed = true;
    }
    if (playing != _playing) {
      _playing = playing;
      changed = true;
    }
    if (_videoLoading) {
      _videoLoading = false;
      changed = true;
    }
    // Keep the media notification in sync.
    audioHandler.pushExternalState(
      playing: playing,
      position: pos,
      duration: dur,
    );
    // Auto-advance when finished.
    if (dur > Duration.zero &&
        pos >= dur - const Duration(milliseconds: 300) &&
        !playing &&
        _queue.length > 1 &&
        !_advancing) {
      _advancing = true;
      if (_repeatOne) {
        c.seekTo(Duration.zero);
        c.play();
        _advancing = false;
      } else {
        next(auto: true).whenComplete(() => _advancing = false);
        return;
      }
    }
    if (changed) notifyListeners();
  }

  Future<void> _disposeVideoController() async {
    final c = _videoController;
    _videoController = null;
    if (c != null) {
      c.removeListener(_onVideoTick);
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  MediaItem _mediaItemFor(VideoInfo video) => MediaItem(
        id: video.id,
        title: video.title,
        artist: video.channelName,
        artUri: video.thumbnailUrl.isNotEmpty
            ? Uri.tryParse(video.thumbnailUrl)
            : null,
        duration: video.durationSecs > 0
            ? Duration(seconds: video.durationSecs)
            : null,
      );

  static bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return {'mp4', 'mkv', 'webm', 'mov', '3gp'}.contains(ext);
  }

  /// Best audio-only format (prefer m4a), else null.
  MediaFormat? _pickAudioFormat(List<MediaFormat> formats) {
    final audio = formats.where((f) => f.hasAudio && !f.hasVideo).toList();
    if (audio.isEmpty) return null;
    audio.sort((a, b) => b.fileSize.compareTo(a.fileSize));
    for (final f in audio) {
      if (f.ext == 'm4a') return f;
    }
    return audio.first;
  }

  /// Best progressive (video+audio) mp4, preferring <= 720p.
  MediaFormat? _pickVideoFormat(List<MediaFormat> formats) {
    final progressive = formats
        .where((f) => f.isProgressive && f.ext == 'mp4')
        .toList();
    if (progressive.isEmpty) return null;
    int heightOf(MediaFormat f) {
      final m = RegExp(r'(\d+)\s*p').firstMatch(f.label);
      return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
    }

    progressive.sort((a, b) => heightOf(b).compareTo(heightOf(a)));
    final hd = progressive
        .where((f) {
          final h = heightOf(f);
          return h > 0 && h <= 720;
        })
        .toList();
    return (hd.isNotEmpty ? hd : progressive).first;
  }

  Future<void> togglePlayPause() async {
    if (_videoMode) {
      final c = _videoController;
      if (c == null || !c.value.isInitialized) return;
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
      return;
    }
    if (_playing) {
      await audioHandler.pause();
    } else if (current != null && _audioUrl == null) {
      await _playCurrent();
    } else {
      await audioHandler.play();
    }
  }

  /// Seek by a relative [offset] (e.g. -15s / +30s buttons).
  Future<void> seekBy(Duration offset) async {
    final max = _duration > Duration.zero ? _duration : null;
    var target = _position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (max != null && target > max) target = max;
    await seek(target);
  }

  Future<void> next({bool auto = false}) async {
    if (_queue.length < 2) return;
    if (_shuffle && !auto) {
      _index = (_index + 1 + _queue.length) % _queue.length;
    } else {
      _index = (_index + 1) % _queue.length;
    }
    notifyListeners();
    await _playCurrent();
  }

  Future<void> previous() async {
    if (_queue.length < 2) return;
    // Restart if more than 3s in.
    if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    _index = (_index - 1 + _queue.length) % _queue.length;
    notifyListeners();
    await _playCurrent();
  }

  Future<void> seek(Duration d) async {
    if (_videoMode) {
      await _videoController?.seekTo(d);
      _position = d;
      audioHandler.pushExternalState(
        playing: _playing,
        position: d,
        duration: _duration,
      );
      notifyListeners();
    } else {
      await audioHandler.seek(d);
    }
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _repeatOne = !_repeatOne;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _disposeVideoController();
    super.dispose();
  }
}
