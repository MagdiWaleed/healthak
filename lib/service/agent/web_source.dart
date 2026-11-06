class WebSource {
  final String url;
  final String? title;
  const WebSource({required this.url, this.title});
  Map<String, dynamic> toJson() =>
      {'url': url, if (title != null) 'title': title};
  static WebSource? fromJson(Object? value) {
    if (value is! Map) return null;
    final url = value['url'];
    if (url is! String ||
        !['http', 'https'].contains(Uri.tryParse(url)?.scheme)) {
      return null;
    }
    return WebSource(
        url: url,
        title: value['title'] is String ? value['title'] as String : null);
  }
}
