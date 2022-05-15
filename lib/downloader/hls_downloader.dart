import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:flutter_video_downloader/common.dart';
import 'package:flutter_video_downloader/downloader/downloader.dart';
import 'package:path/path.dart' as path;

const String _keyName = 'enc.key';
const String _m3u8Name = 'index.m3u8';
const String _tsPrefixName = 'index_';
const String TAG_EXTM3U = '#EXTM3U';
const String TAG_EXT_X_ENDLIST = '#EXT-X-ENDLIST';
const String TAG_EXTINF = '#EXTINF:';
const String TAG_EXT_X_KEY = '#EXT-X-KEY';

class _Playlist {
  final List<_UrlSegment> segments;
  final List<String> tags;
  final bool hasEndTag;
  final String keyPlaceholder;
  final String keyUrl;

  bool get hasKey => keyPlaceholder.isNotEmpty && keyUrl.isNotEmpty;

  _Playlist(
      {required this.segments,
      required this.tags,
      required this.hasEndTag,
      required this.keyPlaceholder,
      required this.keyUrl});

  factory _Playlist.empty() => _Playlist(
      segments: [], tags: [], hasEndTag: false, keyPlaceholder: '', keyUrl: '');

  String toM3U8() {
    int index = -1;
    String result = TAG_EXTM3U;
    for (final String tag in tags) {
      if (tag.startsWith(TAG_EXTINF)) {
        index++;
        result += '\n$tag\n${segments[index].filename}';
      } else if (tag.startsWith(TAG_EXT_X_KEY)) {
        if (hasKey) {
          result += '\n${tag.replaceFirst(keyPlaceholder, 'URI="$_keyName"')}';
        } else {
          result += '\n$tag';
        }
      } else {
        result += '\n$tag';
      }
    }
    if (!hasEndTag) {
      result += '\n$TAG_EXT_X_ENDLIST';
    }
    return result;
  }
}

class _UrlSegment {
  final String url;
  final String filename;

  _UrlSegment({
    required this.url,
    required this.filename,
  });
}

class _TsProgress {
  final int loaded;
  final int total;

  _TsProgress({required this.loaded, required this.total});
}

class HlsDownloader with Cancelable implements Downloader {
  final Dio _dio = Dio();
  final Map<String, _TsProgress> _progressMap = {};
  _TsProgress _prevProgress = _TsProgress(loaded: 0, total: 0);
  late final List<_UrlSegment> _chunkUrls;
  Timer? _timer;
  late final String _saveDir;
  late VideoDownloadProgress _downloadProgress;
  ValueChanged<VideoDownloadProgress>? _onProgressUpdate;

  int _maxCount = 5;
  int _runningCount = 0;
  int _failedCount = 0;
  int _completedCount = 0;

  int get _finishedCount => _completedCount + _failedCount;
  int _totalCount = 0;
  int _currentIndex = 0;

  HlsDownloader() {
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
    final _Playlist playlist = await _parseM3u8ByUrl(url);
    if (_downloadProgress.status == VideoDownloadProgressStatus.canceled) {
      return;
    }
    _chunkUrls = playlist.segments;
    if (_chunkUrls.isEmpty) {
      _downloadProgress = _downloadProgress.copyWith(
          status: VideoDownloadProgressStatus.failed, endTime: DateTime.now());
      _sendProgressEvent();
      return;
    }
    _totalCount = _chunkUrls.length;
    if (_chunkUrls.length < _maxCount) {
      _maxCount = _chunkUrls.length;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final _TsProgress currentProgress = _calc(_progressMap);
      final speed = currentProgress.loaded - _prevProgress.loaded;
      VideoDownloadProgress payload = _downloadProgress.copyWith(
        downloaded: currentProgress.loaded,
        total: currentProgress.total,
        speed: speed,
        failedChunksCount: _failedCount,
        completedChunksCount: _completedCount,
        chunksCount: _chunkUrls.length,
        status: VideoDownloadProgressStatus.downloading,
      );
      if (payload.failedChunksCount != 0) {
        payload = payload.copyWith(
            status: VideoDownloadProgressStatus.failed,
            endTime: DateTime.now());
      } else if (payload.failedChunksCount + payload.completedChunksCount ==
          payload.chunksCount) {
        payload = payload.copyWith(
            status: VideoDownloadProgressStatus.success,
            playFile: _m3u8Name,
            endTime: DateTime.now());
      }
      _downloadProgress = payload;
      _sendProgressEvent();
      _prevProgress = currentProgress;
    });
    await File(path.join(_saveDir, _m3u8Name)).writeAsString(playlist.toM3U8());
    if (_chunkUrls.length < _maxCount) {
      _maxCount = _chunkUrls.length;
    }
    for (int i = 0; i < _maxCount; i++) {
      _currentIndex = i;
      _exec(_chunkUrls[_currentIndex]);
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

  void _exec(_UrlSegment segment) {
    _runningCount++;
    final String savePath = path.join(_saveDir, segment.filename);
    _dio.download(
      segment.url,
      savePath,
      cancelToken: getCancelToken(),
      onReceiveProgress: (int loaded, int total) {
        _progressMap[segment.filename] = _TsProgress(
          loaded: loaded,
          total: total,
        );
      },
    ).onError((error, StackTrace stackTrace) async {
      _failedCount++;
      _runningCount--;
      return Response(requestOptions: RequestOptions(path: segment.url));
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
          _exec(_chunkUrls[_currentIndex]);
        }
      }
    }
  }

  _TsProgress _calc(Map<String, _TsProgress> progress) {
    int loaded = 0;
    int total = 0;
    for (var item in progress.values) {
      loaded += item.loaded;
      total += item.total;
    }
    return _TsProgress(loaded: loaded, total: total);
  }

  Future<_Playlist> _parseM3u8ByUrl(String m3u8Url) async {
    try {
      final Uri dataSource = Uri.parse(m3u8Url);
      final res = await _dio.get(
        dataSource.toString(),
        options: Options(responseType: ResponseType.plain),
        cancelToken: getCancelToken(),
      );
      final HlsPlaylist playlist =
          await HlsPlaylistParser.create().parseString(dataSource, res.data);
      if (playlist is HlsMasterPlaylist) {
        if (playlist.mediaPlaylistUrls.isEmpty) {
          return _Playlist.empty();
        }
        return _parseM3u8ByUrl(playlist.mediaPlaylistUrls[0].toString());
      } else if (playlist is HlsMediaPlaylist) {
        String keyPlaceholder = '';
        String keyUrl = '';
        final int keyIndex =
            playlist.tags.indexWhere((item) => item.startsWith(TAG_EXT_X_KEY));
        if (keyIndex != -1) {
          final match =
              RegExp(r'URI="(.*)"').firstMatch(playlist.tags[keyIndex]);
          if (match != null) {
            keyPlaceholder = match.group(0) ?? '';
            keyUrl = match.group(1) ?? '';
          }
        }
        int playIndex = 0;
        final List<_UrlSegment> segments = playlist.segments.map((segment) {
          final String url = _getFullUrl(dataSource.toString(), segment.url!);
          final _UrlSegment _segment =
              _UrlSegment(url: url, filename: '$_tsPrefixName$playIndex.ts');
          playIndex++;
          return _segment;
        }).toList();
        final _Playlist p = _Playlist(
          segments: segments,
          tags: playlist.tags,
          hasEndTag: playlist.hasEndTag,
          keyPlaceholder: keyPlaceholder,
          keyUrl: keyUrl,
        );
        if (p.hasKey) {
          final String keyUrl = _getFullUrl(dataSource.toString(), p.keyUrl);
          p.segments.add(_UrlSegment(url: keyUrl, filename: _keyName));
        }
        return p;
      } else {
        return _Playlist.empty();
      }
    } catch (e) {
      return _Playlist.empty();
    }
  }

  static String _getFullUrl(String baseUrl, String urlComponent) {
    final bool isStartWithHttp = urlComponent.startsWith('http://');
    final bool isStartWithHttps = urlComponent.startsWith('https://');
    if (!isStartWithHttp && !isStartWithHttps) {
      // TODO: relative URl eg: ./ ../
      return path.url.join(path.url.dirname(baseUrl), urlComponent);
    }
    return urlComponent;
  }
}
