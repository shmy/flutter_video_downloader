library flutter_video_downloader;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_video_downloader/common.dart';
import 'package:flutter_video_downloader/downloader/downloader.dart';
import 'package:flutter_video_downloader/downloader/hls_downloader.dart';
import 'package:flutter_video_downloader/downloader/mp4_downloader.dart';
import 'package:nanoid/nanoid.dart';
import 'package:path/path.dart' as path;

class FlutterVideoDownloader extends ChangeNotifier {
  late Downloader _downloader;
  late String _url;
  late String _saveDir;
  late String _savePath;
  late VideoDownloadProgress progress;

  FlutterVideoDownloader({
    required Downloader downloader,
    required String url,
    required String saveDir,
  }) {
    _downloader = downloader;
    _url = url;
    _saveDir = saveDir;
  }

  factory FlutterVideoDownloader.hls(String url, String saveDir) {
    return FlutterVideoDownloader(
      downloader: HlsDownloader(),
      url: url,
      saveDir: saveDir,
    );
  }
  factory FlutterVideoDownloader.mp4(String url, String saveDir) {
    return FlutterVideoDownloader(
      downloader: Mp4Downloader(),
      url: url,
      saveDir: saveDir,
    );
  }
  Future<void> start() async {
    // _savePath = path.join(_saveDir, nanoid());
    _savePath = path.join(_saveDir, '__test__');
    await _mkdir(_savePath);
    _downloader.download(_url, _savePath, onProgressUpdate: (VideoDownloadProgress progress) {
      this.progress = progress;
      notifyListeners();
    });
  }
  Future<void> cancel() async {
    await _downloader.cancel();
  }

  Future<void> stop() async {
    await _downloader.cancel();
    await Directory(_savePath).delete(recursive: true);
  }

  Future<void> _mkdir(String path) async {
    final Directory directory = Directory(path);
    if ((await directory.exists())) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  }
}
