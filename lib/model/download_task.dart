class DownloadTask {
  final int id;
  final int total;
  final int loaded;
  final int speed;
  final int status;
  final String url;
  final String savedDir;
  final String filename;
  final DateTime createdAt;
  final String extra;

  DownloadTask({
    required this.id,
    required this.total,
    required this.loaded,
    required this.speed,
    required this.status,
    required this.url,
    required this.savedDir,
    required this.filename,
    required this.createdAt,
    required this.extra,
  });

  DownloadTask copyWith({
    int? loaded,
    int? total,
    int? speed,
    int? status,
    String? url,
    String? savedDir,
    String? filename,
    DateTime? createdAt,
    String? extra,
  }) {
    return DownloadTask(
      id: id,
      loaded: loaded ?? this.loaded,
      total: total ?? this.total,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      url: url ?? this.url,
      savedDir: savedDir ?? this.savedDir,
      filename: filename ?? this.filename,
      createdAt: createdAt ?? this.createdAt,
      extra: extra ?? this.extra,
    );
  }

  @override
  String toString() {
    return 'DownloadEvent(id: $id, total: $total, loaded: $loaded, speed: $speed, status: $status, url: $url, savedDir: $savedDir, filename: $filename, createdAt: $createdAt, extra: $extra)';
  }
  factory DownloadTask.fromJSON(Map<String, dynamic> data) => DownloadTask(
    id: data['id'],
    total: data['total'],
    loaded: data['loaded'],
    speed: data['speed'],
    status: data['status'],
    url: data['url'],
    savedDir: data['saved_dir'],
    filename: data['filename'],
    createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at']),
    extra: data['extra'],
  );
  Map<String, dynamic> toJSON() => {
    'id': id,
    'total': total,
    'loaded': loaded,
    'speed': speed,
    'status': status,
    'url': url,
    'saved_dir': savedDir,
    'filename': filename,
    'created_at': createdAt.millisecondsSinceEpoch,
    'extra': extra,
  };
}
