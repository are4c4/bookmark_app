import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark presentation hosts delegate resolver composition', () {
    final factory = File(
      'lib/services/bookmark_presentation_resolver_factory.dart',
    ).readAsStringSync();
    final visual =
        File('lib/widgets/bookmark_visual_image.dart').readAsStringSync();
    final reverseLookup = File(
      'lib/widgets/bookmark_reverse_lookup_dialog.dart',
    ).readAsStringSync();
    final lifecycle =
        File('lib/views/bookmark_lifecycle_page.dart').readAsStringSync();

    expect(factory, contains('repository.workspaceStore.database'));
    expect(factory, contains('BookmarkUrlResolver('));
    expect(factory, contains('BookmarkVisualResolver('));

    for (final source in [visual, reverseLookup, lifecycle]) {
      expect(source, contains('BookmarkPresentationResolverFactory'));
      expect(source, isNot(contains('workspaceStore.database')));
    }

    expect(visual, isNot(contains('BookmarkVisualResolver(')));
    expect(reverseLookup, isNot(contains('BookmarkUrlResolver(')));
    expect(lifecycle, isNot(contains('BookmarkUrlResolver(')));

    // Existing host/test injection seams remain available; this slice only
    // moves low-level resolver construction out of presentation code.
    expect(visual, contains('resolveSource'));
    expect(reverseLookup, contains('resolveUrl'));
    expect(lifecycle, contains('resolveUrl'));
  });
}
