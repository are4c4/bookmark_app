import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('People related Bookmark URL uses canonical Weblink resolver presentation', () {
    final source = File('lib/views/people_management_page.dart').readAsStringSync();

    expect(
      source,
      contains("import '../services/bookmark_presentation_resolver_factory.dart';"),
    );
    expect(source, contains("import '../services/bookmark_url_resolver.dart';"));
    expect(source, contains("import '../widgets/bookmark_resolved_url_text.dart';"));
    expect(source, contains('late final BookmarkUrlResolve _resolveBookmarkUrl;'));
    expect(
      RegExp(
        r'_resolveBookmarkUrl\s*=\s*BookmarkPresentationResolverFactory\.urlFor\(repository\);',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains('subtitle: BookmarkResolvedUrlText('));
    expect(source, contains('resolveUrl: _resolveBookmarkUrl'));
    expect(
      source,
      isNot(contains('subtitle: Text(\n                                    bookmark.url,')),
    );
  });
}
