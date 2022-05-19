import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_video_downloader/constant/constant.dart';
import 'package:flutter_video_downloader/downloader/downloader.dart';
import 'package:flutter_video_downloader/downloader/impl/concurrent_downloader.dart';
import 'package:flutter_video_downloader/model/download_task.dart';
import 'package:flutter_video_downloader/model/parsed_segment.dart';
import 'package:flutter_video_downloader/parser/impl/hls_parser.dart';
import 'package:flutter_video_downloader/parser/impl/http_range_parser.dart';
import 'package:flutter_video_downloader/parser/parser.dart';
import 'package:flutter_video_downloader/runner/runner.dart';
import 'package:flutter_video_downloader/util/sqlite.dart';
import 'package:path/path.dart' as path;

class PoolRunner implements Runner {
  late final FetchCallback _fetchCallback;
  ValueChanged<DownloadTask>? _onUpdated;
  final int _maxRunnerCount = 3;
  int _currentRunnerCount = 0;
  final Map<int, Downloader> _pool = {};

  bool get _canAdd => _currentRunnerCount < _maxRunnerCount;

  void setFetchCallback(FetchCallback callback) {
    _fetchCallback = callback;
  }

  void setOnUpdateCallback(ValueChanged<DownloadTask>? callback) {
    _onUpdated = callback;
  }

  @override
  Future<void> cancel(DownloadTask downloadTask) async {
    _pool[downloadTask.id]?.cancel();
    _pool.remove(downloadTask.id);
    _check();
  }

  @override
  Future<void> enqueue({
    required String url,
    required String savedDir,
    required String extra,
  }) async {
    final DownloadTask task = await Sqlite.createDownloadTask(
        url: url, savedDir: savedDir, extra: extra);
    if (_canAdd) {
      if (task.status == DownloadStatus.idle) {
        _currentRunnerCount++;
        _download(task);
      }
    }
  }

  @override
  Future<void> remove(DownloadTask downloadTask) async {
    await cancel(downloadTask);
    await Sqlite.removeById(downloadTask.id);
    await Directory(downloadTask.savedDir).delete(recursive: true);
    _check();
  }

  @override
  Future<void> retry(DownloadTask downloadTask) async  {
    _onTaskUpdate(downloadTask.copyWith(status: DownloadStatus.idle));
    _check();
  }

  @override
  Future<void> resumeAll() async {
    _check();
  }
  Future<void> _check() async {
    if (_canAdd) {
      _currentRunnerCount++;
      DownloadTask? task = await Sqlite.getFirstIdle();
      if (task == null) {
        _onDownloadFinished();
        return;
      }
      task = task.copyWith(status: DownloadStatus.fetching);
      await _onTaskUpdate(task);
      _download(task);
    }
  }

  Future<void> _download(DownloadTask task) async {
    final FetchResult fetchResult = await _fetchCallback(task.url, task.extra);
    if (fetchResult.isSuccess) {
      final Parser parser =
          await _getParserByUrl(fetchResult.url, fetchResult.headers);
      final List<ParsedSegment> segments = await parser.parse(fetchResult.url);
      if (segments.isEmpty) {
        _onTaskUpdate(task.copyWith(status: DownloadStatus.failed));
        return;
      }
      task = task.copyWith(
          status: DownloadStatus.downloading,
          filename: parser.runtimeType == HlsParser
              ? hlsM3u8Name
              : path.url.basename(Uri.parse(fetchResult.url).path));
      await _onTaskUpdate(task);

      final Downloader downloader = ConcurrentDownloader(
        maxConcurrentCount: 10,
      );
      _pool[task.id] = downloader;
      _pool[task.id]!.download(
        task,
        segments,
        onProgressUpdate: (DownloadTask task) {
          _onTaskUpdate(task);
        },
        mergeFiles: parser.runtimeType == HttpRangeParser,
      );
    } else {
      _onTaskUpdate(task.copyWith(status: DownloadStatus.failed));
    }
  }

  Future<void> _onTaskUpdate(DownloadTask task) async {
    await Sqlite.updateTask(task);
    _onUpdated?.call(task);
    if ([DownloadStatus.canceled, DownloadStatus.success, DownloadStatus.failed]
        .contains(task.status)) {
      _onDownloadFinished();
    }
  }

  void _onDownloadFinished() {
    _currentRunnerCount--;
    _check();
  }

  Future<Parser> _getParserByUrl(
      String url, Map<String, dynamic> headers) async {
    late Parser parser;
    final Uri uri = Uri.parse(url);
    final String extension = path.url.extension(uri.path).toLowerCase();
    if (extension == '.m3u8') {
      parser = HlsParser();
    } else if (['.flv', '.mp4', '.avi'].contains(extension)) {
      parser = HttpRangeParser();
    } else {
      try {
        final res = await Dio().head(url, options: Options(headers: headers));
        final String contentType =
            res.headers.value(Headers.contentTypeHeader) ?? '';
        if (contentType.startsWith('text/') ||
            contentType.endsWith('vnd.apple.mpegurl')) {
          parser = HlsParser();
        } else {
          parser = HttpRangeParser();
        }
      } catch (e) {
        parser = HttpRangeParser();
      }
    }
    return parser;
  }

}
