import 'package:flutter_video_downloader/constant/constant.dart';
import 'package:flutter_video_downloader/model/download_task.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class Sqlite {
  static Database? _db;
  static const String _tableName = 'downloads';

  static Future<void> init() async {
    final String databasesPath = await getDatabasesPath();
    _db = await openDatabase(
        path.join(databasesPath, 'flutter_video_downloader_data.db'),
        version: 1,
        onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE $_tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      total INTEGER DEFAULT 0,
      loaded INTEGER DEFAULT 0,
      speed INTEGER DEFAULT 0,
      status INTEGER DEFAULT 3,
      url VARCHAR(255) UNIQUE NOT NULL,
      saved_dir VARCHAR(255) DEFAULT NULL,
      filename VARCHAR(255) DEFAULT NULL,
      created_at INTEGER NOT NULL,
      extra TEXT DEFAULT ''
    );
    ''');
  }

  static Future<DownloadTask> createDownloadTask({
    required String url,
    required String savedDir,
    required String extra,
  }) async {
    late DownloadTask task;
    final rows = await _db!.query(_tableName, where: 'url = ?', whereArgs: [url]);
    if (rows.isEmpty) {
      final id = await _db!.insert(_tableName, {
        'url': url,
        'saved_dir': savedDir,
        'filename': '',
        'extra': extra,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      task = await getDownloadTaskById(id);
    } else {
      task = DownloadTask.fromJSON(rows[0]);
    }
    return task;
  }
  static Future<DownloadTask> getDownloadTaskById(int id) async {
    final rows = await _db!.query(_tableName, where: 'id = ?', whereArgs: [id]);
    return DownloadTask.fromJSON(rows[0]);
  }
  static Future<DownloadTask?> getFirstIdle() async {
    final rows = await _db!.query(_tableName, where: 'status = ?', whereArgs: [DownloadStatus.idle], orderBy: 'created_at ASC');
    if (rows.isEmpty) {
      return null;
    }
    return DownloadTask.fromJSON(rows[0]);
  }
  static Future<void> updateTask(DownloadTask task) async {
    await _db!.update(_tableName, task.toJSON(), where: 'id = ?', whereArgs: [task.id]);
  }
  static Future<List<DownloadTask>> getAllUnFinishedTask() async {
    final List rows = await _db!.query(_tableName, where: 'status != ?', whereArgs: [DownloadStatus.success]);
    return rows.map((e) => DownloadTask.fromJSON(e)).toList();
  }
}
