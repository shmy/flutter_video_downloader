import 'package:dio/dio.dart';
import 'package:flutter_video_downloader/model/parsed_segment.dart';
import 'package:flutter_video_downloader/parser/parser.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:path/path.dart' as path;

const String _keyName = 'enc.key';
const String _m3u8Name = 'index.m3u8';
const String _tsPrefixName = 'index_';
const String TAG_EXTM3U = '#EXTM3U';
const String TAG_EXT_X_ENDLIST = '#EXT-X-ENDLIST';
const String TAG_EXTINF = '#EXTINF:';
const String TAG_EXT_X_KEY = '#EXT-X-KEY';

class HlsParser implements Parser {
  final CancelToken _token = CancelToken();

  @override
  Future<List<ParsedSegment>> parse(String url) {
    return _parseM3u8ByUrl(url);
  }

  @override
  void cancel() {
    _token.cancel();
  }

  Future<List<ParsedSegment>> _parseM3u8ByUrl(String url) async {
    try {
      final res = await Dio().get(
        url,
        options: Options(responseType: ResponseType.plain),
        cancelToken: _token,
      );
      final HlsPlaylist playlist = await HlsPlaylistParser.create()
          .parseString(Uri.parse(url), res.data);
      if (playlist is HlsMasterPlaylist) {
        if (playlist.mediaPlaylistUrls.isEmpty) {
          return [];
        }
        return _parseM3u8ByUrl(playlist.mediaPlaylistUrls[0].toString());
      } else if (playlist is HlsMediaPlaylist) {
        String keyPlaceholder = '';
        String keyUrl = '';
        final int keyIndex =
            playlist.tags.indexWhere((item) => item.startsWith(TAG_EXT_X_KEY));
        if (keyIndex != -1) {
          final match =
              RegExp(r'URI="(.*)"').firstMatch(playlist.tags[keyIndex]);
          if (match != null) {
            keyPlaceholder = match.group(0) ?? '';
            keyUrl = match.group(1) ?? '';
          }
        }
        int playIndex = 0;
        final List<ParsedSegment> result = [];
        for (final Segment segment in playlist.segments) {
          final String fullUrl = _getFullUrl(url, segment.url!);
          result.add(ParsedSegment(
            url: fullUrl,
            filename: '$_tsPrefixName$playIndex${path.url.extension(Uri.parse(fullUrl).path)}',
            headers: {},
          ));
          playIndex++;
        }

        result.add(ParsedSegment(
          url: url,
          filename: _m3u8Name,
          headers: {},
          responseBody: _toM3u8(result, playlist, keyPlaceholder, keyUrl),
        ));
        if (keyPlaceholder.isNotEmpty && keyUrl.isNotEmpty) {
          result.add(ParsedSegment(
            url: _getFullUrl(url, keyUrl),
            filename: _keyName,
            headers: {},
          ));
        }
        return result;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  String _toM3u8(List<ParsedSegment> segments, HlsMediaPlaylist playlist,
      String keyPlaceholder, String keyUrl) {
    final bool hasKey = keyPlaceholder.isNotEmpty && keyUrl.isNotEmpty;
    final bool hasEndTag = playlist.hasEndTag;
    int index = -1;
    String result = TAG_EXTM3U;
    for (final String tag in playlist.tags) {
      if (tag.startsWith(TAG_EXTINF)) {
        index++;
        result += '\n$tag\n${segments[index].filename}';
      } else if (tag.startsWith(TAG_EXT_X_KEY)) {
        if (hasKey) {
          result += '\n${tag.replaceFirst(keyPlaceholder, 'URI="$_keyName"')}';
        } else {
          result += '\n$tag';
        }
      } else {
        result += '\n$tag';
      }
    }
    if (!hasEndTag) {
      result += '\n$TAG_EXT_X_ENDLIST';
    }
    return result;
  }

  String _getFullUrl(String baseUrl, String urlComponent) {
    final bool isStartWithHttp = urlComponent.startsWith('http://');
    final bool isStartWithHttps = urlComponent.startsWith('https://');
    if (!isStartWithHttp && !isStartWithHttps) {
      // TODO: relative URl eg: ./ ../
      return path.url.join(path.url.dirname(baseUrl), urlComponent);
    }
    return urlComponent;
  }
}
