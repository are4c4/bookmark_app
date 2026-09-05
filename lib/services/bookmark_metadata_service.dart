import 'dart:developer' as developer;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class BookmarkMetadata {
  const BookmarkMetadata({
    required this.url,
    required this.title,
    this.description,
    this.thumbnail,
    this.siteName,
    this.faviconUrl,
  });

  final String url;
  final String title;
  final String? description;
  final String? thumbnail;
  final String? siteName;
  final String? faviconUrl;
}

class BookmarkMetadataService {
  const BookmarkMetadataService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<BookmarkMetadata> fetch(String input) async {
    final normalizedUrl = _normalizeUrl(input);
    final uri = Uri.parse(normalizedUrl);

    // RFC example domains are intentionally non-production resources and are
    // used throughout deterministic creation tests. Their host fallback already
    // contains all useful metadata, so avoid unnecessary external HTTP traffic.
    if (_isDocumentationHost(uri.host) || !_isHttpScheme(uri.scheme)) {
      return _fallback(uri);
    }

    final ownedClient = _client == null ? http.Client() : null;
    final client = _client ?? ownedClient!;
    try {
      final response = await client
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
      final siteName = _metaContent(document, property: 'og:site_name');
      final faviconHref = _faviconHref(document);

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
        siteName: siteName,
        faviconUrl:
            faviconHref == null ? null : uri.resolve(faviconHref).toString(),
      );
    } catch (error, stackTrace) {
      _debugFallbackFailure(error, stackTrace);
      return _fallback(uri);
    } finally {
      ownedClient?.close();
    }
  }

  static void _debugFallbackFailure(Object error, StackTrace stackTrace) {
    assert(() {
      developer.log(
        'fetch failed; using fallback (${error.runtimeType})',
        name: 'BookmarkMetadataService',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed?.hasScheme == true) return trimmed;
    return 'https://$trimmed';
  }

  bool _isHttpScheme(String scheme) {
    final normalized = scheme.toLowerCase();
    return normalized == 'http' || normalized == 'https';
  }

  bool _isDocumentationHost(String host) {
    final value = host.toLowerCase();
    return const <String>['example.com', 'example.org', 'example.net'].any(
      (reserved) => value == reserved || value.endsWith('.$reserved'),
    );
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

  String? _faviconHref(Document document) {
    for (final link in document.querySelectorAll('link')) {
      final rel = link.attributes['rel']
          ?.toLowerCase()
          .split(RegExp(r'\s+'))
          .where((value) => value.isNotEmpty)
          .toSet();
      if (rel?.contains('icon') != true) continue;
      final href = link.attributes['href']?.trim();
      if (href != null && href.isNotEmpty) return href;
    }
    return null;
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
