import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/backlink_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BacklinkRepository resolves outgoing and incoming entries through focused reads',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );

    final sourceId = await repository.create(
      url: 'https://example.com/source',
      title: 'Source',
    );
    final targetId = await repository.create(
      url: 'https://example.com/target',
      title: 'Target',
    );
    final bookmarks = await repository.watchAll().first;
    final source = bookmarks.singleWhere((bookmark) => bookmark.id == sourceId);
    final target = bookmarks.singleWhere((bookmark) => bookmark.id == targetId);
    final backlinks = BacklinkRepository(repository);

    await backlinks.link(source, target, relationType: 'related');

    final outgoing = await backlinks
        .watchFor(source.id)
        .firstWhere((entries) => entries.isNotEmpty);
    expect(outgoing, hasLength(1));
    expect(outgoing.single.bookmark.id, target.id);
    expect(outgoing.single.relationType, 'related');
    expect(outgoing.single.direction, BacklinkDirection.outgoing);

    final incoming = await backlinks
        .watchFor(target.id)
        .firstWhere((entries) => entries.isNotEmpty);
    expect(incoming, hasLength(1));
    expect(incoming.single.bookmark.id, source.id);
    expect(incoming.single.relationType, 'related');
    expect(incoming.single.direction, BacklinkDirection.incoming);
  });

  test('BacklinkRepository delegates Relation reads instead of reaching into database', () {
    final source =
        File('lib/repositories/backlink_repository.dart').readAsStringSync();

    expect(source, contains('_root.watchRelationsForBookmark(bookmarkId)'));
    expect(source, isNot(contains('lifecycleStore.database')));
    expect(source, isNot(contains('_database.select')));
    expect(source, isNot(contains('final AppDatabase _database')));
  });
}
