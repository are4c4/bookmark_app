import 'package:bookmark_app/services/bookmark_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('metadata fetch resolves site name favicon and preview URLs', () async {
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
    <link rel="shortcut icon" href="/assets/favicon.ico">
  </head>
</html>
''',
          200,
          headers: const {'content-type': 'text/html; charset=utf-8'},
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
  });
}
