import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_video_downloader/flutter_video_downloader.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_video_downloader/parser/impl/hls_parser.dart';
import 'package:flutter_video_downloader/parser/impl/http_range_parser.dart';
import 'package:sqlite_viewer/sqlite_viewer.dart';

class ParserTestPage extends StatelessWidget {
  final String savedDir;

  const ParserTestPage({Key? key, required this.savedDir}) : super(key: key);

  void _hlsParser(String url) async {
    final segments = await HlsParser().parse(url);
    // _download(url, 'index.m3u8', segments);
  }

  void _httpRangeParser(String url) async {
    const filename = 'index.mp4';
    final segments = await HttpRangeParser().parse(url);
    // _download(url, filename, segments);
  }

  // void _download(
    //   String url, String filename, List<ParsedSegment> segments) async {
    // final savedDir = path.join(this.savedDir, 'test8');
    // final DownloadTask task = DownloadTask.initialization(
    //   url: url,
    //   savedDir: savedDir,
    //   filename: filename,
    //   segments: segments,
    // );
    // ConcurrentDownloader(maxConcurrentCount: 10).download(
    //   task,
    //   onProgressUpdate: (event) {
    //     print(event);
    //   },
    //   mergeFiles: true,
    // );
  // }
  void _enqueue(String url) {
    final savedDir = path.join(this.savedDir, 'new1');
    final filename = 'video.mp4';
    final extra = json.encode({'raw_id': 1});
    FlutterVideoDownloader.enqueue(url: url, savedDir: savedDir, filename: filename, extra: extra);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ParserTestPage'),
      ),
      body: ListView(
        children: [
          MaterialButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DatabaseList()));
            },
            child: Text(
                'View Database'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/hls/xgplayer-demo.m3u8'),
            child: Text(
                'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/hls/xgplayer-demo.m3u8'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'https://m3u8.taopianplay.com/taopian/ecd7f271-487e-48d6-9873-9edc06e79ce8/1e995a1c-d91d-4e6a-8716-2f76f90f9394/47916/40be6fca-f3f7-4078-9c9e-aba8d0a3512b/SD/playlist.m3u8'),
            child: Text(
                'https://m3u8.taopianplay.com/taopian/ecd7f271-487e-48d6-9873-9edc06e79ce8/1e995a1c-d91d-4e6a-8716-2f76f90f9394/47916/40be6fca-f3f7-4078-9c9e-aba8d0a3512b/SD/playlist.m3u8'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'https://new.iskcd.com/20220422/e9LNmEMj/index.m3u8'),
            child: Text('https://new.iskcd.com/20220422/e9LNmEMj/index.m3u8'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-720p.mp4'),
            child: Text(
                'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-720p.mp4'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'http://1011.hlsplay.aodianyun.com/demo/game.flv'),
            child: Text('http://1011.hlsplay.aodianyun.com/demo/game.flv'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/flv/xgplayer-demo-360p.flv'),
            child: Text(
                'https://sf1-hscdn-tos.pstatp.com/obj/media-fe/xgplayer_doc_video/flv/xgplayer-demo-360p.flv'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'http://vfx.mtime.cn/Video/2019/02/04/mp4/190204084208765161.mp4'),
            child: Text(
                'http://vfx.mtime.cn/Video/2019/02/04/mp4/190204084208765161.mp4'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'https://om.tc.qq.com/gzc_1000102_0b53juaa4aaabyagna233nrmatodbzaqacsa.f10217.mp4?vkey=B8FF7B7F55477E4F61759024D16042FC4A26ADE09AB3D079620F6716E082F9940475C3F05BFF4CE5C535D4606AEAAE9CC5CFBC2E3CE1AA0113CA1A0FCB8F66ABE551BA9D7C81091487AF35FED70973796509EC6ACDFBC2DB2A21FC3B7F14D6DE7771E3CA43903EC1B020CE28F7549E5710A50D1B4713685A96777AEE8122CC43E31437CBA68B1D81'),
            child: Text(
                'https://om.tc.qq.com/gzc_1000102_0b53juaa4aaabyagna233nrmatodbzaqacsa.f10217.mp4?vkey=B8FF7B7F55477E4F61759024D16042FC4A26ADE09AB3D079620F6716E082F9940475C3F05BFF4CE5C535D4606AEAAE9CC5CFBC2E3CE1AA0113CA1A0FCB8F66ABE551BA9D7C81091487AF35FED70973796509EC6ACDFBC2DB2A21FC3B7F14D6DE7771E3CA43903EC1B020CE28F7549E5710A50D1B4713685A96777AEE8122CC43E31437CBA68B1D81'),
          ),
          MaterialButton(
            onPressed: () => _enqueue(
                'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/90/57/718985790/718985790_nb2-1-112.flv?e=ig8euxZM2rNcNbNBhWdVhwdlhbU1hwdVhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&nbs=1&deadline=1652939943&gen=playurlv2&os=cosbv&oi=3723238199&trid=740dc71f35fc442385868b73d873e469u&platform=pc&upsig=249c07fa589395f69cd45dd2ca4b1f3e&uparams=e,uipk,nbs,deadline,gen,os,oi,trid,platform&mid=1588095118&bvc=vod&nettype=0&orderid=0,3&agrr=1&bw=251623&logo=80000000&_t=1652932640317&295yun&qq=755758836'),
            child: Text(
                'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/90/57/718985790/718985790_nb2-1-112.flv?e=ig8euxZM2rNcNbNBhWdVhwdlhbU1hwdVhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&nbs=1&deadline=1652939943&gen=playurlv2&os=cosbv&oi=3723238199&trid=740dc71f35fc442385868b73d873e469u&platform=pc&upsig=249c07fa589395f69cd45dd2ca4b1f3e&uparams=e,uipk,nbs,deadline,gen,os,oi,trid,platform&mid=1588095118&bvc=vod&nettype=0&orderid=0,3&agrr=1&bw=251623&logo=80000000&_t=1652932640317&295yun&qq=755758836'),
          ),
        ],
      ),
    );
  }
}
