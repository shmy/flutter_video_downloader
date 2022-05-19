library flutter_video_downloader;

import 'package:flutter/cupertino.dart';
import 'package:flutter_video_downloader/model/download_task.dart';
import 'package:flutter_video_downloader/runner/impl/pool_runner.dart';
import 'package:flutter_video_downloader/runner/runner.dart';
import 'package:flutter_video_downloader/util/sqlite.dart';

class FlutterVideoDownloader {
  static late Runner _runner;
  static final List<ValueChanged<DownloadTask>> _listeners = [];

  static Future<void> init({required FetchCallback fetchCallback}) async {
    _runner = PoolRunner()
      ..setFetchCallback(fetchCallback)
      ..setOnUpdateCallback((value) {
        for (final ValueChanged<DownloadTask> listener in _listeners) {
          listener(value);
        }
      });
    await Sqlite.init();
  }

  static void addListener(ValueChanged<DownloadTask> listener) {
    _listeners.add(listener);
  }

  static void removeListener(ValueChanged<DownloadTask> listener) {
    _listeners.remove(listener);
  }

  static Future<List<DownloadTask>> queryList() {
    return Sqlite.getAllUnFinishedTask();
  }

  static void enqueue({
    required String url,
    required String savedDir,
    required String extra,
  }) {
    _runner.enqueue(
      url: url,
      savedDir: savedDir,
      extra: extra,
    );
  }
  static void cancel(DownloadTask task) {
    _runner.cancel(task);
  }
  static void retry(DownloadTask task) {
    _runner.retry(task);
  }
}