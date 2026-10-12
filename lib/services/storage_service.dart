import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A downloaded media file on disk.
class StoredFile {
  final File file;
  final String name;
  final int sizeBytes;
  final DateTime modified;
  final bool isAudio;

  StoredFile({
    required this.file,
    required this.name,
    required this.sizeBytes,
    required this.modified,
    required this.isAudio,
  });
}

/// Lists / deletes / renames / shares downloaded files in /MusicPlayer.
class StorageService {
  static const _folder = 'MusicPlayer';
  static const _mediaExts = {'mp4', 'm4a', 'mp3', 'webm', 'mkv', 'aac'};

  Future<Directory> downloadDir() async {
    Directory base;
    if (Platform.isAndroid) {
      base = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final dir = Directory('${base.path}/$_folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Must match DownloadManager's resolved path: external storage on
  /// Android, app documents elsewhere.
  Future<String> downloadDirDisplayPath() async => (await downloadDir()).path;

  Future<List<StoredFile>> listFiles() async {
    final dir = await downloadDir();
    final out = <StoredFile>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      final ext = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : '';
      if (!_mediaExts.contains(ext)) continue;
      final stat = await entity.stat();
      out.add(StoredFile(
        file: entity,
        name: name,
        sizeBytes: stat.size,
        modified: stat.modified,
        isAudio: ext == 'm4a' || ext == 'mp3' || ext == 'aac',
      ));
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<int> totalBytes() async {
    var total = 0;
    for (final f in await listFiles()) {
      total += f.sizeBytes;
    }
    return total;
  }

  Future<void> delete(StoredFile f) async {
    if (await f.file.exists()) {
      await f.file.delete();
    }
  }

  Future<StoredFile> rename(StoredFile f, String newName) async {
    var clean = newName.trim();
    if (clean.isEmpty) throw ArgumentError('Name cannot be empty');
    final oldExt = f.name.contains('.') ? '.${f.name.split('.').last}' : '';
    if (!clean.toLowerCase().endsWith(oldExt.toLowerCase())) {
      clean = '$clean$oldExt';
    }
    final newPath =
        '${f.file.parent.path}${Platform.pathSeparator}$clean';
    final renamed = await f.file.rename(newPath);
    final stat = await renamed.stat();
    return StoredFile(
      file: renamed,
      name: clean,
      sizeBytes: stat.size,
      modified: stat.modified,
      isAudio: f.isAudio,
    );
  }

  Future<void> share(StoredFile f) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.file.path)], text: f.name),
    );
  }
}
