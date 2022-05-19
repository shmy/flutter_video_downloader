import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_video_downloader/constant/constant.dart';
import 'package:flutter_video_downloader/downloader/downloader.dart';
import 'package:flutter_video_downloader/model/download_task.dart';
import 'package:flutter_video_downloader/model/parsed_segment.dart';
import 'package:path/path.dart' as path;

mixin _Cancelable {
  final List<CancelToken> _cancelTokens = [];

  CancelToken _getCancelToken() {
    final CancelToken token = CancelToken();
    _cancelTokens.add(token);
    return token;
  }

  void _cancelAll() {
    for (final CancelToken _cancelToken in _cancelTokens) {
      _cancelToken.cancel();
    }
  }
}

class _ChunkDownloadProgress {
  final int loaded;
  final int total;

  _ChunkDownloadProgress({required this.loaded, required this.total});
}

enum _MergeStatus { idle, progress, success, failed }

class ConcurrentDownloader with _Cancelable implements Downloader {
  late final int _maxConcurrentCount;
  late final String _saveDir;
  final Dio _dio = Dio();
  final List<ParsedSegment> _segments = [];
  final Map<String, _ChunkDownloadProgress> _tasks = {};
  late DownloadTask _downloadTask;
  _ChunkDownloadProgress _prevProgress =
      _ChunkDownloadProgress(loaded: 0, total: 0);

  int get _totalCount => _segments.length;
  int _runningCount = 0;
  int _failedCount = 0;
  int _completedCount = 0;

  int get _finishedCount => _completedCount + _failedCount;
  int _currentIndex = 0;
  Timer? _timer;
  ValueChanged<DownloadTask>? _onProgressUpdate;
  bool _mergeFiles = false;
  _MergeStatus _mergeStatus = _MergeStatus.idle;

  ConcurrentDownloader({required int maxConcurrentCount}) {
    _maxConcurrentCount = maxConcurrentCount;
  }

  @override
  Future<void> cancel() async {
    _stopTimer();
    _cancelAll();
    _downloadTask = _downloadTask.copyWith(status: DownloadStatus.canceled, speed: 0);
    _sendEvent();
  }

  @override
  Future<void> download(DownloadTask task, List<ParsedSegment> segments,
      {ValueChanged<DownloadTask>? onProgressUpdate,
      bool mergeFiles = false}) async {
    _downloadTask = task;
    _segments.clear();
    _segments.addAll(segments);
    _saveDir = _downloadTask.savedDir;
    _onProgressUpdate = onProgressUpdate;
    _mergeFiles = mergeFiles;
    _startTimer();
    _sendEvent();
    final int maxConcurrentCount =
        _totalCount < _maxConcurrentCount ? _totalCount : _maxConcurrentCount;
    for (int i = 0; i < maxConcurrentCount; i++) {
      _currentIndex = i;
      _exec(_segments[_currentIndex]);
    }
  }

  void _sendEvent() {
    _onProgressUpdate?.call(_downloadTask);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final _ChunkDownloadProgress currentProgress = _calc(_tasks);
      final speed = currentProgress.loaded - _prevProgress.loaded;
      _downloadTask = _downloadTask.copyWith(
        loaded: currentProgress.loaded,
        total: currentProgress.total,
        speed: speed,
        status: DownloadStatus.downloading,
      );
      if (_mergeStatus != _MergeStatus.idle) {
        switch (_mergeStatus) {
          case _MergeStatus.success:
            _downloadTask =
                _downloadTask.copyWith(status: DownloadStatus.success, speed: 0);
            _stopTimer();
            break;
          case _MergeStatus.failed:
            _downloadTask =
                _downloadTask.copyWith(status: DownloadStatus.failed, speed: 0);
            _stopTimer();
            break;
          default:
            break;
        }
      } else {
        if (_failedCount > 0) {
          _downloadTask = _downloadTask.copyWith(status: DownloadStatus.failed, speed: 0);
          // 发生错误
          _stopTimer();
        } else if (_finishedCount == _totalCount) {
          if (_mergeFiles) {
            _mergeDownloadedFiles();
          } else {
            _downloadTask =
                _downloadTask.copyWith(status: DownloadStatus.success, speed: 0);
            // 下载完成
            _stopTimer();
          }
        }
      }

      _sendEvent();
      _prevProgress = currentProgress;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  _ChunkDownloadProgress _calc(Map<String, _ChunkDownloadProgress> progress) {
    int loaded = 0;
    int total = 0;
    for (final _ChunkDownloadProgress item in progress.values) {
      loaded += item.loaded;
      total += item.total;
    }
    return _ChunkDownloadProgress(loaded: loaded, total: total);
  }

  void _onChunkDownloadSuccess() {
    _completedCount++;
    _runningCount--;
    _check();
  }

  void _onChunkDownloadFail() {
    _failedCount++;
    _runningCount--;
  }

  void _exec(ParsedSegment item) {
    final String savedPath = path.join(_saveDir, item.filename);

    if (item.responseBody != null) {
      File(savedPath).writeAsString(item.responseBody!).catchError((error) {
        _onChunkDownloadFail();
      }).then((value) {
        _onChunkDownloadSuccess();
      });
      return;
    }
    _dio.download(
      item.url,
      savedPath,
      cancelToken: _getCancelToken(),
      options: Options(headers: item.headers),
      onReceiveProgress: (int loaded, int total) {
        _tasks[item.filename] = _ChunkDownloadProgress(
          loaded: loaded,
          total: total == -1 ? loaded : total,
        );
      },
    ).catchError((error) {
      _onChunkDownloadFail();
      return Response(requestOptions: RequestOptions(path: ''));
    }).then((value) {
      _onChunkDownloadSuccess();
      _check();
    });
  }

  void _check() {
    if (_finishedCount < _totalCount) {
      if (_runningCount < _maxConcurrentCount) {
        if (_totalCount > _currentIndex + 1) {
          _currentIndex++;
          _exec(_segments[_currentIndex]);
        }
      }
    }
  }

  Future<void> _mergeDownloadedFiles() async {
    _mergeStatus = _MergeStatus.progress;
    try {
      final File outFile =
          File(path.join(_downloadTask.savedDir, _downloadTask.filename));
      if ((await outFile.exists())) {
        await outFile.delete();
      }
      final IOSink ioSink = outFile.openWrite(mode: FileMode.writeOnlyAppend);
      final List<File> files = [];
      for (final ParsedSegment segment in _segments) {
        final File file =
            File(path.join(_downloadTask.savedDir, segment.filename));
        files.add(file);
        await ioSink.addStream(file.openRead());
      }
      await ioSink.flush();
      await ioSink.close();
      await Future.wait(files.map((e) => e.delete()).toList());
      _mergeStatus = _MergeStatus.success;
    } catch (e) {
      debugPrint(e.toString());
      _mergeStatus = _MergeStatus.failed;
    }
  }
}
