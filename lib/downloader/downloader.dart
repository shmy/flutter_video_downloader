import 'package:flutter/foundation.dart';
import 'package:flutter_video_downloader/model/download_task.dart';
import 'package:flutter_video_downloader/model/parsed_segment.dart';

abstract class Downloader {
  Future<void> download(
    DownloadTask task, List<ParsedSegment> segments, {
    ValueChanged<DownloadTask>? onProgressUpdate,
    bool mergeFiles,
  });

  Future<void> cancel();
}
