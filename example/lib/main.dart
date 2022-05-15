import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_video_downloader/flutter_video_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

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
  FlutterVideoDownloader? videoDownloader;

  @override
  void initState() {
    _startServer();
    super.initState();
  }

  String _format2Mb(int size) {
    return (size / 1024 / 1024).toStringAsFixed(2) + "Mb";
  }

  Future<void> _start() async {
    final dir = await findLocalPath();
    // videoDownloader = FlutterVideoDownloader.mp4(
    //     'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-720p.mp4',
    videoDownloader = FlutterVideoDownloader.hls(
        'http://192.168.2.161:3000/190204084208765161/index.m3u8',
        dir)
      ..start()
      ..addListener(() {
        final progress = videoDownloader!.progress;
        print(
            '(${progress.status})${progress.startTime}: ${_format2Mb(progress.downloaded)}/${_format2Mb(progress.total)} ${_format2Mb(progress.speed)}/s [${progress.failedChunksCount}+${progress.completedChunksCount}/${progress.chunksCount}] ${progress.saveDir}/${progress.playFile} ${progress.endTime}');
      });
    // await FlutterVideoDownloader.download(
    //     // 'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/hls/xgplayer-demo.m3u8',
    //   // 'https://m3u8.taopianplay.com/taopian/ecd7f271-487e-48d6-9873-9edc06e79ce8/1e995a1c-d91d-4e6a-8716-2f76f90f9394/47916/40be6fca-f3f7-4078-9c9e-aba8d0a3512b/SD/playlist.m3u8',
    //   // 'https://baidu.sd-play.com/20211029/dLDDtlZq/index.m3u8',
    //   // 'https://new.iskcd.com/20220513/syYiD8Bk/index.m3u8',
    //   // 'http://192.168.2.161:3000/190204084208765161/index.m3u8',
    //   // 'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-720p.mp4',
    //   'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/flv/xgplayer-demo-360p.flv',
    //   // 'http://150.158.130.238:4436/jm/api/?key=M7PJgp5NuoUDgsfQ9crSJQ%3D%3D.m3u8',
    //     dir,
    //     isHls: false, onProgressUpdate: (progress)  {
    //     print('(${progress.status})${progress.startTime}: ${_format2Mb(progress.downloaded)}/${_format2Mb(progress.total)} ${_format2Mb(progress.speed)}/s [${progress.failedChunksCount}+${progress.completedChunksCount}/${progress.chunksCount}] ${progress.saveDir}/${progress.playFile} ${progress.endTime}');
    // });
    // await FlutterVideoDownloader.download('https://m3u8.taopianplay.com/taopian/ecd7f271-487e-48d6-9873-9edc06e79ce8/1e995a1c-d91d-4e6a-8716-2f76f90f9394/47916/40be6fca-f3f7-4078-9c9e-aba8d0a3512b/SD/playlist.m3u8', isHls: true);
    // await FlutterVideoDownloader.download('https://new.iskcd.com/20220422/e9LNmEMj/index.m3u8', isHls: true);
  }
  void _cancel() {
    videoDownloader?.cancel();
  }
  void _stop() {
    videoDownloader?.stop();
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
    final dir = await findLocalPath();
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
      body: ListView(
        children: [
          MaterialButton(
            onPressed: _start,
            child: const Text('start'),
          ),
          MaterialButton(
            onPressed: _cancel,
            child: const Text('cancel'),
          ),
          MaterialButton(
            onPressed: _stop,
            child: const Text('stop'),
          ),
        ],
      ),
    );
  }
}
