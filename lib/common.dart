const String userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36 Edg/101.0.1210.39';

enum VideoDownloadProgressStatus {
  idle,
  downloading,
  transcoding,
  failed,
  success,
  canceled
}

class VideoDownloadProgress {
  final int downloaded;
  final int total;
  final int speed;
  final int failedChunksCount;
  final int completedChunksCount;
  final int chunksCount;
  final VideoDownloadProgressStatus status;
  final String saveDir;
  final String? playFile;
  final DateTime? startTime;
  final DateTime? endTime;

  VideoDownloadProgress({
    required this.downloaded,
    required this.total,
    required this.speed,
    required this.failedChunksCount,
    required this.completedChunksCount,
    required this.chunksCount,
    required this.status,
    required this.saveDir,
    this.playFile,
    this.startTime,
    this.endTime,
  });

  factory VideoDownloadProgress.start({required String saveDir}) =>
      VideoDownloadProgress(
        downloaded: 0,
        total: 0,
        speed: 0,
        failedChunksCount: 0,
        completedChunksCount: 0,
        chunksCount: 0,
        status: VideoDownloadProgressStatus.idle,
        saveDir: saveDir,
        startTime: DateTime.now(),
      );

  VideoDownloadProgress copyWith({
    int? downloaded,
    int? total,
    int? speed,
    int? failedChunksCount,
    int? completedChunksCount,
    int? chunksCount,
    VideoDownloadProgressStatus? status,
    String? saveDir,
    String? playFile,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return VideoDownloadProgress(
      downloaded: downloaded ?? this.downloaded,
      total: total ?? this.total,
      speed: speed ?? this.speed,
      failedChunksCount: failedChunksCount ?? this.failedChunksCount,
      completedChunksCount: completedChunksCount ?? this.completedChunksCount,
      chunksCount: chunksCount ?? this.chunksCount,
      status: status ?? this.status,
      saveDir: saveDir ?? this.saveDir,
      playFile: playFile ?? this.playFile,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
