import 'package:flutter_video_downloader/model/parsed_segment.dart';

abstract class Parser {
  Future<List<ParsedSegment>> parse(String url);

  void cancel();
}
