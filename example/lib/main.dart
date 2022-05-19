import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_video_downloader/flutter_video_downloader.dart';
import 'package:flutter_video_downloader/model/download_task.dart';
import 'package:flutter_video_downloader/runner/runner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:sqlite_viewer/sqlite_viewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late String dir;
  List<DownloadTask> _tasks = [];

  @override
  void initState() {
    _startServer();
    init();
    super.initState();
  }

  void init() async {
    await FlutterVideoDownloader.init(
        fetchCallback: (String url, String extra) async {
      return FetchResult(isSuccess: true, url: url, headers: {});
    });
    FlutterVideoDownloader.addListener((value) {
      _refreshList();
    });
    final urls = [
      'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/hls/xgplayer-demo.m3u8',
      'https://m3u8.taopianplay.com/taopian/ecd7f271-487e-48d6-9873-9edc06e79ce8/1e995a1c-d91d-4e6a-8716-2f76f90f9394/47916/40be6fca-f3f7-4078-9c9e-aba8d0a3512b/SD/playlist.m3u8',
      'https://new.iskcd.com/20220422/e9LNmEMj/index.m3u8',
      'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-720p.mp4',
      // 'http://1011.hlsplay.aodianyun.com/demo/game.flv',
      'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/flv/xgplayer-demo-360p.flv',
      'http://vfx.mtime.cn/Video/2019/02/04/mp4/190204084208765161.mp4',
    ];
    int index = 0;
    for (var element in urls) {
      _enqueue(element, index.toString());
      index++;
    }
  }

  void _enqueue(String url, dirName) {
    final savedDir = path.join(dir, dirName);
    final filename = 'video.mp4';
    final extra = json.encode({'raw_id': 1});
    FlutterVideoDownloader.enqueue(
        url: url, savedDir: savedDir, filename: filename, extra: extra);
  }

  void _refreshList() async {
    final list = await FlutterVideoDownloader.queryList();
    _tasks.clear();
    setState(() {
      _tasks.addAll(list);
    });
  }

  String _format2Mb(int size) {
    return (size / 1024 / 1024).toStringAsFixed(2) + "Mb";
  }

  Future<String> findLocalPath() async {
    String dir = '';
    if (Platform.isAndroid) {
      dir = (await getApplicationSupportDirectory()).absolute.path;
    } else if (Platform.isIOS) {
      dir = (await getApplicationDocumentsDirectory()).absolute.path;
    }
    if (dir != '') {
      dir = path.join(dir, 'downloads');
      final Directory directory = Directory(dir);
      if (!(await directory.exists())) {
        await directory.create(recursive: true);
      }
    }
    return dir;
  }

  void _startServer() async {
    dir = await findLocalPath();
    var handler = createStaticHandler(
      dir,
      listDirectories: true,
    );
    io.serve(handler, InternetAddress.anyIPv6, 1994, shared: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          MaterialButton(
            onPressed: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => DatabaseList()));
            },
            child: Text('view database'),
          ),
          Expanded(
            child: ListView.builder(
              itemBuilder: (context, index) {
                final item = _tasks[index];
                return ListTile(
                  title: Text(path.url.basename(item.url)),
                  subtitle: Text(
                      '${_format2Mb(item.loaded)}/${_format2Mb(item.total)} ${_format2Mb(item.speed)}/s'),
                  trailing: Text(item.status.toString()),
                  onTap: () => FlutterVideoDownloader.retry(item),
                );
              },
              itemCount: _tasks.length,
            ),
          ),
        ],
      ),
    );
  }
}
