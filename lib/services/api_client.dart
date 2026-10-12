import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/video_info.dart';

/// Thrown for any extractor-server communication failure.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// HTTP client for the extractor server.
/// Every request is a POST with the `X-API-Key` header.
class ApiClient {
  final String baseUrl;
  final String apiKey;

  const ApiClient({required this.baseUrl, required this.apiKey});

  Map<String, String> get _headers => {
        'X-API-Key': apiKey,
        'Content-Type': 'application/json',
      };

  Future<dynamic> _post(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    late Uri uri;
    try {
      uri = Uri.parse(baseUrl).replace(
        path: '${Uri.parse(baseUrl).path}$path'.replaceAll('//', '/'),
        queryParameters: query.isEmpty ? null : query,
      );
    } catch (_) {
      throw const ApiException('Invalid server URL. Check Settings.');
    }

    http.Response resp;
    try {
      resp = await http
          .post(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException(
        'Server timed out. Is the extractor server running?',
      );
    } catch (e) {
      throw ApiException('Could not reach server: $e');
    }

    if (resp.statusCode != 200) {
      throw ApiException(
        'Server error ${resp.statusCode}: ${_shortBody(resp.body)}',
      );
    }
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      throw const ApiException('Server returned invalid JSON.');
    }
  }

  String _shortBody(String body) {
    final t = body.trim();
    return t.length > 160 ? '${t.substring(0, 160)}...' : t;
  }

  List<VideoInfo> _parseVideoList(dynamic decoded) {
    final raw = decoded is Map && decoded['results'] is List
        ? decoded['results'] as List
        : decoded is List
            ? decoded
            : decoded is Map && decoded['videos'] is List
                ? decoded['videos'] as List
                : <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => VideoInfo.fromJson(Map<String, dynamic>.from(m)))
        .where((v) => v.videoUrl.isNotEmpty || v.id.isNotEmpty)
        .toList();
  }

  /// `POST /search` with query params `q` and `limit`.
  Future<List<VideoInfo>> search(String q, {int limit = 25}) async {
    final decoded = await _post('/search', {'q': q, 'limit': '$limit'});
    return _parseVideoList(decoded);
  }

  /// POST /trending
  Future<List<VideoInfo>> trending() async {
    final decoded = await _post('/trending');
    return _parseVideoList(decoded);
  }

  /// `POST /formats` with query param `url`.
  Future<List<MediaFormat>> formats(String videoUrl) async {
    final decoded = await _post('/formats', {'url': videoUrl});
    final raw = decoded is Map && decoded['formats'] is List
        ? decoded['formats'] as List
        : decoded is List
            ? decoded
            : <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => MediaFormat.fromJson(Map<String, dynamic>.from(m)))
        .where((f) => f.formatId.isNotEmpty)
        .toList();
  }

  /// `POST /stream` with query params `url` and `format_id`; returns the stream URL.
  Future<String> streamUrl(String videoUrl, String formatId) async {
    final decoded = await _post('/stream', {
      'url': videoUrl,
      'format_id': formatId,
    });
    final url = decoded is Map
        ? (decoded['url'] ?? decoded['stream_url'] ?? decoded['streamUrl'])
        : null;
    if (url == null || url.toString().isEmpty) {
      throw const ApiException('Server did not return a stream URL.');
    }
    return url.toString();
  }

  /// `POST /playlist` with query param `url`; returns the entries list.
  /// The server may not implement this; callers handle ApiException.
  Future<List<VideoInfo>> playlist(String playlistUrl) async {
    final decoded = await _post('/playlist', {'url': playlistUrl});
    return _parseVideoList(
      decoded is Map ? decoded['entries'] ?? decoded : decoded,
    );
  }
}
