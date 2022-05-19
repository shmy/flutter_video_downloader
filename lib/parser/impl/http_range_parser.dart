import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_video_downloader/model/parsed_segment.dart';
import 'package:flutter_video_downloader/parser/parser.dart';
import 'package:path/path.dart' as path;

class _Range {
  final String url;
  final String filename;
  final int start;
  final int end;

  _Range(
      {required this.url,
      required this.filename,
      required this.start,
      required this.end});

  @override
  String toString() {
    return '_Range(url: $url, filename: $filename, start: $start, end: $end)';
  }
}

class HttpRangeParser implements Parser {
  final CancelToken _token = CancelToken();
  final int _chunkSize = 1024 * 1024 * 2;

  @override
  void cancel() {
    _token.cancel();
  }

  @override
  Future<List<ParsedSegment>> parse(String url) async {
    final List<_Range> rages = await _getRangeList(url);
    return rages.map((e) {
      final Map<String, dynamic> headers = {};
      if (e.start != -1) {
        String range = 'bytes=${e.start}-';
        if (e.end != 0) {
          range += '${e.end}';
        }
        headers[HttpHeaders.rangeHeader] = range;
      }
      return ParsedSegment(
        url: e.url,
        filename: e.filename,
        headers: headers,
      );
    }).toList();
  }

  Future<List<_Range>> _getRangeList(String url) async {
    final extension = path.url.extension(Uri.parse(url).path);
    final List<_Range> defaultList = [
      _Range(start: -1, end: -1, url: url, filename: '0$extension')
    ];
    try {
      final res = await Dio()
          .head(url, cancelToken: _token, options: Options(headers: {}));
      final List<String> acceptRanges =
          res.headers[HttpHeaders.acceptRangesHeader] ?? [];
      final List<String> contentLength =
          res.headers[HttpHeaders.contentLengthHeader] ?? [];
      if (acceptRanges.isEmpty || contentLength.isEmpty) {
        return defaultList;
      }
      if (acceptRanges.first.toLowerCase() != 'bytes') {
        return defaultList;
      }
      final totalSize = int.tryParse(contentLength.first) ?? 0;
      if (totalSize == 0) {
        return defaultList;
      }
      final List<_Range> rangeList = [];
      final int chunksCount = (totalSize / _chunkSize).ceil();
      _Range _getLastRangeInList() {
        return rangeList.isEmpty
            ? _Range(start: 0, end: -1, url: '', filename: '')
            : rangeList.last;
      }

      for (int i = 0; i < chunksCount - 1; i++) {
        final _Range prevRange = _getLastRangeInList();
        rangeList.add(_Range(
          url: url,
          filename: '$i$extension',
          start: prevRange.end + 1,
          end: prevRange.end + 1 + _chunkSize,
        ));
      }
      final _Range laseRange = _getLastRangeInList();
      rangeList.add(_Range(
        url: url,
        filename: '${chunksCount - 1}$extension',
        start: laseRange.end + 1,
        end: 0,
      ));
      return rangeList;
    } catch (e) {
      return defaultList;
    }
  }
}
