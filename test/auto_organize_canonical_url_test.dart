import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/auto_organize_service.dart';
import 'package:bookmark_app/services/bookmark_url_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late WorkspaceStore workspaceStore;
  late BookmarkLifecycleStore lifecycleStore;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceStore = WorkspaceStore(database);
    workspaceId = await workspaceStore.initialize();
    lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
  });

  tearDown(() async {
    await database.close();
  });

  Future<BookmarkItem> createBookmark(
    AutoOrganizeService autoOrganize, {
    String url = 'https://legacy.example/stale',
  }) async {
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
      autoOrganizeService: autoOrganize,
    );
    final id = await repository.create(
      url: url,
      title: 'Example bookmark',
      inbox: true,
    );
    return (await repository.watchAll().first)
        .singleWhere((bookmark) => bookmark.id == id);
  }

  test('auto-organize URL rules prefer the resolved canonical Weblink URL',
      () async {
    final autoOrganize = AutoOrganizeService(
      database,
      resolveUrl: (_) async => const BookmarkUrlSource(
        kind: BookmarkUrlSourceKind.canonicalWeblink,
        value: 'https://canonical.example/article',
      ),
    );
    final bookmark = await createBookmark(autoOrganize);

    await autoOrganize.createRule(
      name: 'Canonical host',
      matchField: AutoOrganizeMatchField.url,
      keyword: 'canonical.example',
      tagName: 'canonical',
    );
    await autoOrganize.createRule(
      name: 'Stale legacy host',
      matchField: AutoOrganizeMatchField.url,
      keyword: 'legacy.example',
      tagName: 'legacy',
    );

    final result = await autoOrganize.applyToAll([bookmark]);
    final tags = await database.watchAllTags().first;

    expect(result.rulesMatched, 1);
    expect(result.bookmarksChanged, 1);
    expect(tags.map((tag) => tag.name), contains('canonical'));
    expect(tags.map((tag) => tag.name), isNot(contains('legacy')));
  });

  test('auto-organize falls back to legacy URL when resolution fails',
      () async {
    final autoOrganize = AutoOrganizeService(
      database,
      resolveUrl: (_) async => throw StateError('resolver unavailable'),
    );
    final bookmark = await createBookmark(autoOrganize);

    await autoOrganize.createRule(
      name: 'Legacy fallback',
      matchField: AutoOrganizeMatchField.url,
      keyword: 'legacy.example',
      tagName: 'fallback',
    );

    final result = await autoOrganize.applyToAll([bookmark]);
    final tags = await database.watchAllTags().first;

    expect(result.rulesMatched, 1);
    expect(result.bookmarksChanged, 1);
    expect(tags.map((tag) => tag.name), contains('fallback'));
  });

  test('BookmarkRepository composes auto-organize with workspace URL resolver',
      () async {
    final source = await File(
      'lib/data/bookmark_repository.dart',
    ).readAsString();

    expect(
      source,
      contains('AutoOrganizeService(_database, workspaceId: workspaceId)'),
    );
    expect(
      source,
      isNot(contains('AutoOrganizeService(_database);')),
    );
  });
}
