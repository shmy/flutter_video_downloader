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

  void setFetchCallback(FetchCallback callback) {
    _fetchCallback = callback;
  }

  void setOnUpdateCallback(ValueChanged<DownloadTask>? callback) {
    _onUpdated = callback;
  }

  @override
  void cancel(DownloadTask downloadTask) {}

  @override
  void enqueue({
    required String url,
    required String savedDir,
    required String filename,
    required String extra,
  }) {
    Sqlite.createDownloadTask(
        url: url, savedDir: savedDir, filename: filename, extra: extra);
    _check();
  }

  @override
  void remove(DownloadTask downloadTask) {
    // TODO: implement remove
  }

  @override
  void retry(DownloadTask downloadTask) {
    // TODO: implement retry
  }

  void _check() {
    if (_currentRunnerCount < _maxRunnerCount) {
      _currentRunnerCount++;
      _startNext();
    }
  }

  Future<void> _startNext() async {
     DownloadTask? task = await Sqlite.getFirstIdle();
    if (task == null) {
      return;
    }
     task = task.copyWith(status: DownloadStatus.fetching);
    _onUpdated?.call(task);
    final FetchResult fetchResult = await _fetchCallback(task.url, task.extra);
    if (fetchResult.isSuccess) {
      final Parser parser =
          await _getParserByUrl(fetchResult.url, fetchResult.headers);
      final List<ParsedSegment> segments = await parser.parse(fetchResult.url);
      if (segments.isEmpty) {
        _onUpdated?.call(task.copyWith(status: DownloadStatus.failed));
        _onDownloadFailed();
        return;
      }
      final Downloader downloader =
          ConcurrentDownloader(maxConcurrentCount: 10);
      _pool[task.id] = downloader;
      _pool[task.id]!.download(task, segments, onProgressUpdate: (DownloadTask task) {
        Sqlite.updateTask(task);
        _onUpdated?.call(task);
      });
    } else {
      _onUpdated?.call(task.copyWith(status: DownloadStatus.failed));
      _onDownloadFailed();
    }
  }
  void _onDownloadFailed() {
    _currentRunnerCount --;
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
