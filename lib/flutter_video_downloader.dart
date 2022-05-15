library flutter_video_downloader;

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_video_downloader/common.dart';
import 'package:flutter_video_downloader/downloader/downloader.dart';
import 'package:flutter_video_downloader/downloader/hls_downloader.dart';
import 'package:flutter_video_downloader/downloader/mp4_downloader.dart';
import 'package:path/path.dart' as path;

class FlutterVideoDownloader extends ChangeNotifier {
  late Downloader _downloader;
  late String _url;
  late String _saveDir;
  late VideoDownloadProgress progress;

  FlutterVideoDownloader({
    required String url,
    required String saveDir,
  }) {
    _url = url;
    _saveDir = saveDir;
  }

  Future<void> start() async {
    late Downloader downloader;
    final Uri uri = Uri.parse(_url);
    final String extension = path.url.extension(uri.path).toLowerCase();
    debugPrint(extension);
    if (extension == '.m3u8') {
      downloader = HlsDownloader();
    } else if (['.flv', '.mp4', '.avi'].contains(extension)) {
      downloader = Mp4Downloader();
    } else {
      try {
        final res = await Dio().head(_url);
        final String contentType =
            res.headers.value(Headers.contentTypeHeader) ?? '';
        if (contentType.startsWith('text/') ||
            contentType.endsWith('vnd.apple.mpegurl')) {
          downloader = HlsDownloader();
        } else {
          downloader = Mp4Downloader();
        }
      } catch (e) {
        downloader = Mp4Downloader();
      }
    }
    _downloader = downloader;
    progress = VideoDownloadProgress.start(saveDir: _saveDir);
    await _mkdir(_saveDir);
    _downloader.download(_url, _saveDir,
        onProgressUpdate: (VideoDownloadProgress progress) {
      this.progress = progress;
      notifyListeners();
    });
  }

  Future<void> cancel() async {
    await _downloader.cancel();
  }

  Future<void> stop() async {
    await _downloader.cancel();
    await Directory(_saveDir).delete(recursive: true);
  }

  Future<void> _mkdir(String path) async {
    final Directory directory = Directory(path);
    if (!(await directory.exists())) {
      await directory.create(recursive: true);
    }
  }
}
