import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark detail URL wiring keeps canonical Weblink authority', () {
    final source =
        File('lib/widgets/bookmark_detail_panel.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../services/bookmark_presentation_resolver_factory.dart';",
      ),
    );
    expect(
      source,
      contains("import '../services/bookmark_url_resolver.dart';"),
    );
    expect(source, contains('final BookmarkUrlResolve? resolveUrl;'));
    expect(source, contains('late BookmarkUrlResolve _resolveBookmarkUrl;'));
    expect(source, contains('late Future<BookmarkUrlSource?> _resolvedUrl;'));

    expect(
      RegExp(
        r'_resolveBookmarkUrl\s*=\s*widget\.resolveUrl\s*\?\?\s*BookmarkPresentationResolverFactory\.urlFor\(widget\.repository\);',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'_resolvedUrl\s*=\s*_resolveBookmarkUrl\(widget\.bookmark\);',
      ).hasMatch(source),
      isTrue,
    );

    expect(
      RegExp(
        r'final\s+effectiveUrl\s*=\s*url\s*\?\?\s*await\s+_preferredUrl\(\);',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(r'url:\s*effectiveUrl,').hasMatch(source),
      isTrue,
    );

    expect(source, contains('FutureBuilder<BookmarkUrlSource?>('));
    expect(
      RegExp(
        r'final\s+value\s*=\s*snapshot\.data\?\.value\s*\?\?\s*bookmark\.url;',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(r'_urlController\.text\s*=\s*value;').hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(r'_editingUrlBaseline\s*=\s*value;').hasMatch(source),
      isTrue,
    );
    expect(source, contains('onPressed: _openResolvedUrl'));

    expect(
      RegExp(r'url:\s*url\s*\?\?\s*widget\.bookmark\.url').hasMatch(source),
      isFalse,
    );
    expect(
      RegExp(r'message:\s*bookmark\.url').hasMatch(source),
      isFalse,
    );
    expect(
      RegExp(r'_compactUrl\(bookmark\.url\)').hasMatch(source),
      isFalse,
    );
    expect(
      RegExp(
        r'onPressed:\s*\(\)\s*=>\s*_openUrl\(bookmark\.url\)',
      ).hasMatch(source),
      isFalse,
    );
  });
}
