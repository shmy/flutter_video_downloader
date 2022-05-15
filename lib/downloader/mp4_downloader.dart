import 'dart:async';
import 'dart:io';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_video_downloader/common.dart';
import 'package:flutter_video_downloader/downloader/downloader.dart';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';

class _DownloadProgress {
  final int loaded;
  final int total;

  _DownloadProgress({required this.loaded, required this.total});
}

class _Range {
  final String url;
  final String filename;
  final int start;
  final int end;

  _Range(
      {required this.url,
      required this.filename,
      required this.start,
      required this.end});

  @override
  String toString() {
    return '_Range(url: $url, filename: $filename, start: $start, end: $end)';
  }
}

class Mp4Downloader with Cancelable implements Downloader {
  final Dio _dio = Dio();
  final int _chunkSize = 1024 * 1024 * 2;
  final Map<String, _DownloadProgress> _progressMap = {};
  late final List<_Range> rangeList;
  late final String _saveDir;
  late VideoDownloadProgress _downloadProgress;
  ValueChanged<VideoDownloadProgress>? _onProgressUpdate;
  Timer? _timer;
  int _maxCount = 5;
  int _runningCount = 0;
  int _failedCount = 0;
  int _completedCount = 0;
  _DownloadProgress _prevProgress = _DownloadProgress(loaded: 0, total: 0);

  int get _finishedCount => _completedCount + _failedCount;
  int _totalCount = 0;
  int _currentIndex = 0;

  Mp4Downloader() {
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      // logPrint: print, // specify log function (optional)
      retries: 3, // retry count (optional)
      retryDelays: const [
        // set delays between retries (optional)
        Duration(seconds: 1), // wait 1 sec before first retry
        Duration(seconds: 2), // wait 2 sec before second retry
        Duration(seconds: 3), // wait 3 sec before third retry
      ],
    ));
  }

  void _sendProgressEvent() {
    _onProgressUpdate?.call(_downloadProgress);
    if (isFinished) {
      _timer?.cancel();
    }
  }

  bool get isFinished => [
        VideoDownloadProgressStatus.failed,
        VideoDownloadProgressStatus.success,
        VideoDownloadProgressStatus.canceled
      ].contains(_downloadProgress.status);

  @override
  Future<void> download(
    String url,
    String saveDir, {
    ValueChanged<VideoDownloadProgress>? onProgressUpdate,
  }) async {
    _onProgressUpdate = onProgressUpdate;
    _saveDir = saveDir;
    _downloadProgress = VideoDownloadProgress.start(saveDir: _saveDir);
    _sendProgressEvent();
    rangeList = await _getRangeList(url);
    if (_downloadProgress.status == VideoDownloadProgressStatus.canceled) {
      return;
    }
    _totalCount = rangeList.length;
    if (_totalCount == 0) {
      _downloadProgress = _downloadProgress.copyWith(
          status: VideoDownloadProgressStatus.failed, endTime: DateTime.now());
      _sendProgressEvent();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final _DownloadProgress currentProgress = _calc(_progressMap);
      final speed = currentProgress.loaded - _prevProgress.loaded;
      if (_downloadProgress.status == VideoDownloadProgressStatus.transcoding) {
        _sendProgressEvent();
        return;
      }
      VideoDownloadProgress payload = _downloadProgress.copyWith(
        downloaded: currentProgress.loaded,
        total: currentProgress.total,
        speed: speed,
        failedChunksCount: _failedCount,
        completedChunksCount: _completedCount,
        chunksCount: rangeList.length,
        status: VideoDownloadProgressStatus.downloading,
      );
      if (payload.failedChunksCount != 0) {
        payload = payload.copyWith(
            status: VideoDownloadProgressStatus.failed,
            endTime: DateTime.now());
      } else if (payload.failedChunksCount + payload.completedChunksCount ==
              payload.chunksCount &&
          _downloadProgress.status != VideoDownloadProgressStatus.transcoding) {
        payload =
            payload.copyWith(status: VideoDownloadProgressStatus.transcoding);
        _mergeFiles();
      }
      _downloadProgress = payload;
      _sendProgressEvent();
      _prevProgress = currentProgress;
    });
    if (rangeList.length < _maxCount) {
      _maxCount = rangeList.length;
    }
    for (int i = 0; i < _maxCount; i++) {
      _currentIndex = i;
      _exec(rangeList[_currentIndex]);
    }
  }

  @override
  Future<void> cancel() async {
    if (isFinished) {
      return;
    }
    cancelAll();
    _downloadProgress = _downloadProgress.copyWith(
        status: VideoDownloadProgressStatus.canceled);
    _sendProgressEvent();
  }

  void _exec(_Range range) {
    final String savePath = path.join(_saveDir, range.filename);
    final int start = range.start;
    final String end = range.end == 0 ? '' : range.end.toString();
    final Map<String, dynamic> headers = {};
    if (start != -1) {
      headers[HttpHeaders.rangeHeader] = 'bytes=$start-$end';
    }
    _dio.download(
      range.url,
      savePath,
      cancelToken: getCancelToken(),
      options: Options(headers: headers),
      onReceiveProgress: (int loaded, int total) {
        _progressMap[range.filename] = _DownloadProgress(
          loaded: loaded,
          total: total,
        );
      },
    ).onError((error, StackTrace stackTrace) async {
      _failedCount++;
      _runningCount--;
      return Response(requestOptions: RequestOptions(path: range.url));
    }).then((value) {
      _completedCount++;
      _runningCount--;
      _check();
    });
  }

  void _check() {
    if (_finishedCount < _totalCount) {
      if (_runningCount < _maxCount) {
        if (_totalCount > _currentIndex + 1) {
          _currentIndex++;
          _exec(rangeList[_currentIndex]);
        }
      }
    }
  }

  _DownloadProgress _calc(Map<String, _DownloadProgress> progress) {
    int loaded = 0;
    int total = 0;
    for (var item in progress.values) {
      loaded += item.loaded;
      total += item.total;
    }
    return _DownloadProgress(loaded: loaded, total: total);
  }

  Future<void> _mergeFiles() async {
    try {
      final extension = path.extension(rangeList.first.filename);
      final filename = 'index$extension';
      final File outFile = File(path.join(_saveDir, filename));
      if ((await outFile.exists())) {
        await outFile.delete();
      }
      final IOSink ioSink = outFile.openWrite(mode: FileMode.writeOnlyAppend);
      final List<File> files = [];
      for (final _Range range in rangeList) {
        final File file = File(path.join(_saveDir, range.filename));
        files.add(file);
        await ioSink.addStream(file.openRead());
      }
      await ioSink.flush();
      await ioSink.close();
      await Future.wait(files.map((e) => e.delete()).toList());
      _downloadProgress = _downloadProgress.copyWith(
          status: VideoDownloadProgressStatus.success,
          playFile: filename,
          endTime: DateTime.now());
    } catch (e) {
      _downloadProgress = _downloadProgress.copyWith(
          status: VideoDownloadProgressStatus.failed, endTime: DateTime.now());
    }
    _sendProgressEvent();
  }

  Future<List<_Range>> _getRangeList(String url) async {
    final extension = path.url.extension(url);
    final List<_Range> defaultList = [
      _Range(start: -1, end: -1, url: url, filename: '0$extension')
    ];
    try {
      final res = await _dio.head(url, cancelToken: getCancelToken());
      final List<String> acceptRanges =
          res.headers[HttpHeaders.acceptRangesHeader] ?? [];
      final List<String> contentLength =
          res.headers[HttpHeaders.contentLengthHeader] ?? [];
      if (acceptRanges.isEmpty || contentLength.isEmpty) {
        return defaultList;
      }
      if (acceptRanges.first.toLowerCase() != 'bytes') {
        return defaultList;
      }
      final totalSize = int.tryParse(contentLength.first) ?? 0;
      if (totalSize == 0) {
        return defaultList;
      }
      final List<_Range> rangeList = [];
      final int chunksCount = (totalSize / _chunkSize).ceil();
      _Range _getLastRangeInList() {
        return rangeList.isEmpty
            ? _Range(start: 0, end: -1, url: '', filename: '')
            : rangeList.last;
      }

      for (int i = 0; i < chunksCount - 1; i++) {
        final _Range prevRange = _getLastRangeInList();
        rangeList.add(_Range(
          url: url,
          filename: '$i$extension',
          start: prevRange.end + 1,
          end: prevRange.end + 1 + _chunkSize,
        ));
      }
      final _Range laseRange = _getLastRangeInList();
      rangeList.add(_Range(
        url: url,
        filename: '${chunksCount - 1}$extension',
        start: laseRange.end + 1,
        end: 0,
      ));
      return rangeList;
    } catch (e) {
      return defaultList;
    }
  }
}
