/// A video (or audio track) returned by the extractor server.
class VideoInfo {
  final String id;
  final String title;
  final String thumbnailUrl;
  final int durationSecs;
  final String channelName;
  final int viewCount;
  final String videoUrl;

  /// True when [videoUrl] is a local file path instead of a remote URL.
  final bool isLocal;

  const VideoInfo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.durationSecs,
    required this.channelName,
    required this.viewCount,
    required this.videoUrl,
    this.isLocal = false,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    String str(dynamic v) => v == null ? '' : v.toString();
    int num(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    }

    final id = str(json['id'] ?? json['videoId'] ?? json['video_id']);
    final url = str(
      json['videoUrl'] ?? json['video_url'] ?? json['url'] ?? json['webpageUrl'],
    );
    return VideoInfo(
      id: id.isEmpty ? url : id,
      title: str(json['title']),
      thumbnailUrl: str(
        json['thumbnailUrl'] ?? json['thumbnail_url'] ?? json['thumbnail'],
      ),
      durationSecs: num(json['durationSecs'] ?? json['duration_secs'] ?? json['duration']),
      channelName: str(
        json['channelName'] ?? json['channel_name'] ?? json['channel'] ?? json['uploader'],
      ),
      viewCount: num(json['viewCount'] ?? json['view_count'] ?? json['views']),
      videoUrl: url,
      isLocal: json['isLocal'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'durationSecs': durationSecs,
        'channelName': channelName,
        'viewCount': viewCount,
        'videoUrl': videoUrl,
        'isLocal': isLocal,
      };
}

/// One downloadable format for a video (from POST /formats).
class MediaFormat {
  final String formatId;
  final String label; // e.g. "720p", "128kbps"
  final String ext; // mp4, m4a, webm...
  final int fileSize; // bytes, -1 if unknown
  final bool hasVideo;
  final String? directUrl; // server may provide a direct URL

  const MediaFormat({
    required this.formatId,
    required this.label,
    required this.ext,
    this.fileSize = -1,
    this.hasVideo = true,
    this.directUrl,
  });

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    String str(dynamic v) => v == null ? '' : v.toString();
    int num(dynamic v) {
      if (v == null) return -1;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? -1;
    }

    return MediaFormat(
      formatId: str(json['formatId'] ?? json['format_id'] ?? json['id']),
      label: str(
        json['label'] ?? json['quality'] ?? json['format'] ?? json['abr'],
      ),
      ext: str(json['ext'] ?? 'mp4'),
      fileSize: num(json['fileSize'] ?? json['filesize'] ?? json['size']),
      hasVideo: json['hasVideo'] ?? json['has_video'] ?? true,
      directUrl: json['directUrl'] ?? json['direct_url'] ?? json['url'],
    );
  }
}

/// 3725 -> "1:02:05", 95 -> "1:35"
String formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '';
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// 1500000 -> "1.5M", 2300 -> "2.3K"
String formatCount(int count) {
  if (count >= 1000000) {
    final v = count / 1000000;
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)}M';
  }
  if (count >= 1000) {
    final v = count / 1000;
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)}K';
  }
  return count.toString();
}

/// 1048576 -> "1.0 MB"
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
