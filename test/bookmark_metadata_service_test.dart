import 'package:bookmark_app/services/bookmark_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('metadata fetch resolves site name favicon and resource facts', () async {
    final service = BookmarkMetadataService(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://www.resource.test/articles/entry',
        );
        return http.Response(
          '''
<html>
  <head>
    <title>HTML fallback title</title>
    <meta property="og:title" content="Readable article title">
    <meta property="og:description" content="Resource description">
    <meta property="og:site_name" content="Resource Site">
    <meta property="og:image" content="../media/preview.jpg">
    <meta property="article:published_time" content="2026-09-05T12:34:56+09:00">
    <link rel="shortcut icon" href="/assets/favicon.ico">
  </head>
</html>
''',
          200,
          headers: const {'content-type': 'Text/HTML; charset=utf-8'},
        );
      }),
    );

    final metadata = await service.fetch(
      'HTTPS://WWW.Resource.Test/articles/entry',
    );

    expect(metadata.url, 'https://www.resource.test/articles/entry');
    expect(metadata.title, 'Readable article title');
    expect(metadata.description, 'Resource description');
    expect(metadata.siteName, 'Resource Site');
    expect(
      metadata.thumbnail,
      'https://www.resource.test/media/preview.jpg',
    );
    expect(
      metadata.faviconUrl,
      'https://www.resource.test/assets/favicon.ico',
    );
    expect(metadata.contentType, 'text/html');
    expect(metadata.publishedDate, '2026-09-05T12:34:56+09:00');
  });

  test('itemprop published date is used and malformed dates are ignored', () async {
    var responseIndex = 0;
    final service = BookmarkMetadataService(
      client: MockClient((request) async {
        responseIndex += 1;
        final published = responseIndex == 1
            ? '<meta itemprop="datePublished" content="2026-09-04">'
            : '<meta property="article:published_time" content="not-a-date">';
        return http.Response(
          '<html><head>$published</head></html>',
          200,
          headers: const {'content-type': 'application/xhtml+xml; charset=UTF-8'},
        );
      }),
    );

    final itemprop = await service.fetch('https://resource.test/first');
    final malformed = await service.fetch('https://resource.test/second');

    expect(itemprop.publishedDate, '2026-09-04');
    expect(itemprop.contentType, 'application/xhtml+xml');
    expect(malformed.publishedDate, isNull);
  });

  test('non-http metadata requests remain local fallback only', () async {
    var requested = false;
    final service = BookmarkMetadataService(
      client: MockClient((request) async {
        requested = true;
        return http.Response('unexpected', 200);
      }),
    );

    final metadata = await service.fetch('mailto:reader@resource.test');

    expect(requested, isFalse);
    expect(metadata.url, 'mailto:reader@resource.test');
    expect(metadata.title, 'mailto:reader@resource.test');
    expect(metadata.siteName, isNull);
    expect(metadata.faviconUrl, isNull);
    expect(metadata.contentType, isNull);
    expect(metadata.publishedDate, isNull);
  });
}
