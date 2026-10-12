import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../models/video_info.dart';
import 'api_client.dart';
import 'settings_service.dart';

/// Global audio/video playback state with queue support.
/// Plays the best audio format for music; falls back to best video format.
class PlayerService extends ChangeNotifier {
  final SettingsService settings;

  PlayerService({required this.settings});

  VideoPlayerController? _controller;
  final List<VideoInfo> _queue = [];
  int _index = -1;
  bool _loading = false;
  String? _error;
  bool _shuffle = false;
  bool _repeatOne = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

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

  void _attach(VideoPlayerController c) {
    c.addListener(_onTick);
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final dur = c.value.duration;
    final playing = c.value.isPlaying;
    var changed = false;
    if (pos != _position) {
      _position = pos;
      changed = true;
    }
    if (dur != _duration) {
      _duration = dur;
      changed = true;
    }
    if (playing != _playing) {
      _playing = playing;
      changed = true;
    }
    // Auto-advance when finished.
    if (dur > Duration.zero &&
        pos >= dur &&
        !c.value.isPlaying &&
        _queue.length > 1) {
      if (_repeatOne) {
        c.seekTo(Duration.zero);
        c.play();
      } else {
        next(auto: true);
        return;
      }
    }
    if (changed) notifyListeners();
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _playing = false;
    if (c != null) {
      c.removeListener(_onTick);
      await c.dispose();
    }
  }

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
    notifyListeners();
    await _disposeController();
    try {
      final formats =
          await settings.apiClient.formats(video.videoUrl);
      final format = _pickAudioFormat(formats) ??
          (formats.isNotEmpty ? formats.first : null);
      if (format == null) {
        throw const ApiException('No playable formats found.');
      }
      final url = format.directUrl ??
          await settings.apiClient
              .streamUrl(video.videoUrl, format.formatId);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _attach(controller);
      await controller.initialize();
      _controller = controller;
      _loading = false;
      notifyListeners();
      await controller.play();
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

  /// Best audio-only format (prefer m4a), else null.
  MediaFormat? _pickAudioFormat(List<MediaFormat> formats) {
    final audio = formats.where((f) => !f.hasVideo).toList();
    if (audio.isEmpty) return null;
    audio.sort((a, b) => b.fileSize.compareTo(a.fileSize));
    for (final f in audio) {
      if (f.ext == 'm4a') return f;
    }
    return audio.first;
  }

  Future<void> togglePlayPause() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
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
    await _controller?.seekTo(d);
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
    _disposeController();
    super.dispose();
  }
}
