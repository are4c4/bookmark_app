import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark presentation hosts delegate resolver composition', () {
    final factory = File(
      'lib/services/bookmark_presentation_resolver_factory.dart',
    ).readAsStringSync();
    final visual =
        File('lib/widgets/bookmark_visual_image.dart').readAsStringSync();
    final lifecycle =
        File('lib/views/bookmark_lifecycle_page.dart').readAsStringSync();
    final reverseLookup = File(
      'lib/widgets/bookmark_reverse_lookup_dialog.dart',
    ).readAsStringSync();
    final notionCard = File('lib/widgets/notion_bookmark_card.dart')
        .readAsStringSync();
    final stage1 = File('lib/views/bookmark_unified_stage1_page.dart')
        .readAsStringSync();
    final stage1UrlFactory = RegExp(
      r'BookmarkPresentationResolverFactory\.urlFor\(\s*'
      r'widget\.repository,?\s*\)',
    );
    final stage1DatabaseViewStore = RegExp(
      r'DatabaseViewStore\(\s*'
      r'widget\.repository\.workspaceStore\.database,?\s*\)',
    );

    expect(factory, contains('repository.workspaceStore.database'));
    expect(factory, contains('BookmarkUrlResolver('));
    expect(factory, contains('BookmarkVisualResolver('));

    for (final source in [visual, lifecycle, reverseLookup, notionCard]) {
      expect(source, contains('BookmarkPresentationResolverFactory'));
      expect(source, isNot(contains('workspaceStore.database')));
    }

    expect(visual, isNot(contains('BookmarkVisualResolver(')));
    expect(lifecycle, isNot(contains('BookmarkUrlResolver(')));
    expect(reverseLookup, isNot(contains('BookmarkUrlResolver(')));
    expect(notionCard, isNot(contains('BookmarkUrlResolver(')));

    expect(stage1, contains('BookmarkPresentationResolverFactory'));
    expect(stage1UrlFactory.hasMatch(stage1), isTrue);
    expect(stage1, isNot(contains('BookmarkUrlResolver(')));
    expect(stage1, isNot(contains('services/bookmark_url_resolver.dart')));
    expect(RegExp(r'workspaceStore\.database').allMatches(stage1).length, 1);
    expect(stage1DatabaseViewStore.hasMatch(stage1), isTrue);

    // Existing host/test injection seams remain available; this slice only
    // moves low-level resolver construction out of presentation code.
    expect(visual, contains('resolveSource'));
    expect(lifecycle, contains('resolveUrl'));
    expect(reverseLookup, contains('resolveUrl'));
    expect(notionCard, contains('resolveUrl'));
  });
}
