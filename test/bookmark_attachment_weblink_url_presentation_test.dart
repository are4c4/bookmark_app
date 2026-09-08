import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PDF metadata update preserves canonical Weblink URL', () {
    final source =
        File('lib/widgets/bookmark_attachment_section.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../services/bookmark_presentation_resolver_factory.dart';",
      ),
    );
    expect(
      RegExp(
        r'BookmarkPresentationResolverFactory\.urlFor\(widget\.repository\)\s*\(widget\.bookmark\)',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains('url: resolvedUrl?.value ?? widget.bookmark.url'));
    expect(source, isNot(contains('url: widget.bookmark.url,')));
  });
}
