import 'package:flutter_video_downloader/model/download_task.dart';
class FetchResult {
  final bool isSuccess;
  final String url;
  final Map<String, dynamic> headers;

  FetchResult({
    required this.isSuccess,
    required this.url,
    required this.headers,
  });
}

typedef FetchCallback = Future<FetchResult> Function(String url, String extra);

abstract class Runner {
  void enqueue({
    required String url,
    required String savedDir,
    required String filename,
    required String extra,
  });

  void cancel(DownloadTask downloadTask);

  void remove(DownloadTask downloadTask);

  void retry(DownloadTask downloadTask);

}
