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
    videoDownloader = FlutterVideoDownloader(
        url: 'http://192.168.2.161:3000/190204084208765161/index.m3u8',
        saveDir: dir)
      ..start()
      ..addListener(() {
        final progress = videoDownloader!.progress;
        print(
            '(${progress.status})${progress.startTime}: ${_format2Mb(progress.downloaded)}/${_format2Mb(progress.total)} ${_format2Mb(progress.speed)}/s [${progress.failedChunksCount}+${progress.completedChunksCount}/${progress.chunksCount}] ${progress.saveDir}/${progress.playFile} ${progress.endTime}');
      });
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
