class ParsedSegment {
  final String url;
  final String filename;
  final Map<String, dynamic> headers;
  final String? responseBody;

  ParsedSegment({
    required this.url,
    required this.filename,
    required this.headers,
    this.responseBody,
  });
  @override
  String toString() {
    return 'ParsedItem(url: $url, filename: $filename, headers: $headers, responseBody: $responseBody)';
  }
}
