import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class BookmarkMetadata {
  const BookmarkMetadata({
    required this.url,
    required this.title,
    this.description,
    this.thumbnail,
  });

  final String url;
  final String title;
  final String? description;
  final String? thumbnail;
}

class BookmarkMetadataService {
  const BookmarkMetadataService();

  Future<BookmarkMetadata> fetch(String input) async {
    final normalizedUrl = _normalizeUrl(input);
    final uri = Uri.parse(normalizedUrl);

    try {
      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                  'AppleWebKit/537.36 bookmark_app/0.1',
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 400) {
        return _fallback(uri);
      }

      final document = html_parser.parse(response.body);

      final ogTitle = _metaContent(document, property: 'og:title');
      final twitterTitle = _metaContent(document, name: 'twitter:title');
      final htmlTitle = document.querySelector('title')?.text.trim();

      final ogDescription = _metaContent(document, property: 'og:description');
      final metaDescription = _metaContent(document, name: 'description');

      final ogImage = _metaContent(document, property: 'og:image');
      final twitterImage = _metaContent(document, name: 'twitter:image');
      final rawImage = ogImage ?? twitterImage;

      return BookmarkMetadata(
        url: uri.toString(),
        title: _firstNonEmpty([
              ogTitle,
              twitterTitle,
              htmlTitle,
            ]) ??
            _fallbackTitle(uri),
        description: _firstNonEmpty([
          ogDescription,
          metaDescription,
        ]),
        thumbnail: rawImage == null ? null : uri.resolve(rawImage).toString(),
      );
    } catch (_) {
      return _fallback(uri);
    }
  }

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  BookmarkMetadata _fallback(Uri uri) {
    return BookmarkMetadata(
      url: uri.toString(),
      title: _fallbackTitle(uri),
    );
  }

  String _fallbackTitle(Uri uri) {
    return uri.host.isEmpty ? uri.toString() : uri.host;
  }

  String? _metaContent(
    Document document, {
    String? property,
    String? name,
  }) {
    final selector = property != null
        ? 'meta[property="$property"]'
        : 'meta[name="$name"]';
    final value = document.querySelector(selector)?.attributes['content']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
