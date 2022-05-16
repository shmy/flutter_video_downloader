import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_video_downloader/common.dart';

mixin Cancelable {
  final List<CancelToken> cancelTokens = [];

  CancelToken getCancelToken() {
    final CancelToken token = CancelToken();
    cancelTokens.add(token);
    return token;
  }

  void cancelAll() {
    for (final CancelToken cancelToken in cancelTokens) {
      cancelToken.cancel('Canceled');
    }
  }
}

abstract class Downloader {
  Future<void> download(
    String url,
    String saveDir,
    Map<String, String> headers, {
    ValueChanged<VideoDownloadProgress>? onProgressUpdate,
  });

  Future<void> cancel();
}
