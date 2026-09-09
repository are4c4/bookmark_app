import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_weblink_tag_convergence_service.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late int workspaceId;
  late ObjectSyncService sync;
  late BookmarkWeblinkTagConvergenceService convergence;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    sync = ObjectSyncService(database);
    convergence = BookmarkWeblinkTagConvergenceService(
      database: database,
      objectStore: sync.objectStore,
      systemObjectStore: sync.systemObjectStore,
    );
  });

  tearDown(() async {
    await sync.dispose();
    await database.close();
  });

  test('empty mirrored Bookmark set does not create Weblink schema', () async {
    await sync.coreBridge.syncAll(workspaceId);

    final report = await convergence.reconcileWorkspace(workspaceId);

    expect(report.bookmarkCount, 0);
    expect(report.weblinkCount, 0);
    expect(report.convergedWeblinkCount, 0);
    expect(report.unchangedWeblinkCount, 0);
    expect(report.mutatedWeblinkObjectIds, isEmpty);
    expect(
      await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ),
      isNull,
    );
  });

  test('copies only direct Tags and is idempotent', () async {
    final parentId = await _createTag(database, 'Parent');
    final childId = await _createTag(database, 'Child', parentTagId: parentId);
    final bookmarkId = await _createBookmark(
      database,
      workspaceId: workspaceId,
      url: 'https://example.com/article',
      title: 'Article',
    );
    await _attachLegacyTag(database, bookmarkId: bookmarkId, tagId: childId);
    await _syncPrerequisites(sync, workspaceId);

    final first = await convergence.reconcileWorkspace(workspaceId);

    expect(first.bookmarkCount, 1);
    expect(first.weblinkCount, 1);
    expect(first.convergedWeblinkCount, 1);
    expect(first.unchangedWeblinkCount, 0);
    expect(first.mutatedWeblinkObjectIds, hasLength(1));

    final state = await _canonicalState(sync, workspaceId);
    final childObjectId = await sync.tagBridge.objectIdForLegacyTag(
      workspaceId,
      childId,
    );
    final parentObjectId = await sync.tagBridge.objectIdForLegacyTag(
      workspaceId,
      parentId,
    );
    expect(childObjectId, isNotNull);
    expect(parentObjectId, isNotNull);
    expect(state.tagIds, <int>[childObjectId!]);
    expect(state.tagIds, isNot(contains(parentObjectId)));
    expect(state.edges.map((edge) => edge.targetObjectId).toList(), <int>[
      childObjectId,
    ]);

    final second = await convergence.reconcileWorkspace(workspaceId);
    expect(second.bookmarkCount, 1);
    expect(second.weblinkCount, 1);
    expect(second.convergedWeblinkCount, 0);
    expect(second.unchangedWeblinkCount, 1);
    expect(second.mutatedWeblinkObjectIds, isEmpty);
    expect((await _canonicalState(sync, workspaceId)).tagIds, state.tagIds);
  });

  test(
    'equivalent Tags on Bookmarks sharing one Weblink converge once',
    () async {
      final tagId = await _createTag(database, 'Shared');
      final firstBookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'HTTPS://EXAMPLE.COM:443/shared',
        title: 'First',
      );
      final secondBookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/shared',
        title: 'Second',
      );
      await _attachLegacyTag(
        database,
        bookmarkId: firstBookmarkId,
        tagId: tagId,
      );
      await _attachLegacyTag(
        database,
        bookmarkId: secondBookmarkId,
        tagId: tagId,
      );
      await _syncPrerequisites(sync, workspaceId);

      final report = await convergence.reconcileWorkspace(workspaceId);

      expect(report.bookmarkCount, 2);
      expect(report.weblinkCount, 1);
      expect(report.convergedWeblinkCount, 1);
      expect(report.mutatedWeblinkObjectIds, hasLength(1));
      final tagObjectId = await sync.tagBridge.objectIdForLegacyTag(
        workspaceId,
        tagId,
      );
      expect(tagObjectId, isNotNull);
      expect((await _canonicalState(sync, workspaceId)).tagIds, <int>[
        tagObjectId!,
      ]);
    },
  );

  test(
    'conflicting Bookmark Tag sets fail closed with zero Weblink mutation',
    () async {
      final firstTagId = await _createTag(database, 'First');
      final secondTagId = await _createTag(database, 'Second');
      final firstBookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/collision',
        title: 'First',
      );
      final secondBookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'HTTPS://EXAMPLE.COM:443/collision',
        title: 'Second',
      );
      await _attachLegacyTag(
        database,
        bookmarkId: firstBookmarkId,
        tagId: firstTagId,
      );
      await _attachLegacyTag(
        database,
        bookmarkId: secondBookmarkId,
        tagId: secondTagId,
      );
      await _syncPrerequisites(sync, workspaceId);

      await expectLater(
        convergence.reconcileWorkspace(workspaceId),
        throwsStateError,
      );

      await _expectNoCanonicalWeblinkTagsSchema(sync, workspaceId);
    },
  );

  test(
    'pre-existing different Weblink Tags are preserved on conflict',
    () async {
      final firstTagId = await _createTag(database, 'Initial');
      final secondTagId = await _createTag(database, 'Later');
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/preserved',
        title: 'Preserved',
      );
      await _attachLegacyTag(
        database,
        bookmarkId: bookmarkId,
        tagId: firstTagId,
      );
      await _syncPrerequisites(sync, workspaceId);
      await convergence.reconcileWorkspace(workspaceId);
      final initial = await _canonicalState(sync, workspaceId);

      await database.customStatement(
        'DELETE FROM bookmark_tags WHERE bookmark_id = ?',
        [bookmarkId],
      );
      await _attachLegacyTag(
        database,
        bookmarkId: bookmarkId,
        tagId: secondTagId,
      );
      await _syncPrerequisites(sync, workspaceId);

      await expectLater(
        convergence.reconcileWorkspace(workspaceId),
        throwsStateError,
      );

      final after = await _canonicalState(sync, workspaceId);
      expect(after.tagIds, initial.tagIds);
      expect(
        after.edges.map((edge) => edge.targetObjectId).toList(),
        initial.edges.map((edge) => edge.targetObjectId).toList(),
      );
    },
  );

  test(
    'legacy-only Tag change advances canonical Weblink with prior snapshot',
    () async {
      final firstTagId = await _createTag(database, 'Before');
      final secondTagId = await _createTag(database, 'After');
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/live-change',
        title: 'Live change',
      );
      await _attachLegacyTag(
        database,
        bookmarkId: bookmarkId,
        tagId: firstTagId,
      );
      await _syncPrerequisites(sync, workspaceId);
      await convergence.reconcileWorkspace(workspaceId);
      final previous = await convergence.captureSourceSnapshot(workspaceId);
      final bookmarkObjectId = await _bookmarkObjectId(
        database,
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
      );

      await database.customStatement(
        'DELETE FROM bookmark_tags WHERE bookmark_id = ?',
        [bookmarkId],
      );
      await _attachLegacyTag(
        database,
        bookmarkId: bookmarkId,
        tagId: secondTagId,
      );
      await _syncPrerequisites(sync, workspaceId);

      final report = await convergence.reconcileBookmarkObjects(
        workspaceId,
        bookmarkObjectIds: <int>[bookmarkObjectId],
        previousSource: previous,
      );

      expect(report.convergedWeblinkCount, 1);
      expect(report.mutatedWeblinkObjectIds, hasLength(1));
      final secondTagObjectId = await sync.tagBridge.objectIdForLegacyTag(
        workspaceId,
        secondTagId,
      );
      expect(secondTagObjectId, isNotNull);
      expect((await _canonicalState(sync, workspaceId)).tagIds, <int>[
        secondTagObjectId!,
      ]);
    },
  );

  test(
    'source Relation index drift fails closed before Weblink Tag write',
    () async {
      final tagId = await _createTag(database, 'Drifted');
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/drift',
        title: 'Drift',
      );
      await _attachLegacyTag(database, bookmarkId: bookmarkId, tagId: tagId);
      await _syncPrerequisites(sync, workspaceId);

      final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.bookmarkSystemKey,
      ))!;
      final tags = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Tags',
      );
      final bookmarkObject = (await sync.objectStore.listObjects(
        bookmarkType.id,
      )).single;
      await database.customStatement(
        'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
        [bookmarkObject.id, tags.id],
      );

      await expectLater(
        convergence.reconcileWorkspace(workspaceId),
        throwsStateError,
      );

      await _expectNoCanonicalWeblinkTagsSchema(sync, workspaceId);
    },
  );
}

Future<void> _syncPrerequisites(ObjectSyncService sync, int workspaceId) async {
  await sync.coreBridge.syncAll(workspaceId);
  await sync.bookmarkWeblinkBridge.syncWorkspace(workspaceId);
}

Future<int> _createTag(
  AppDatabase database,
  String name, {
  int? parentTagId,
}) async {
  await database.customStatement(
    'INSERT INTO tags(name, parent_tag_id) VALUES (?, ?)',
    [name, parentTagId],
  );
  return (await database
          .customSelect(
            'SELECT id FROM tags WHERE name = ?',
            variables: [Variable<String>(name)],
          )
          .getSingle())
      .read<int>('id');
}

Future<int> _createBookmark(
  AppDatabase database, {
  required int workspaceId,
  required String url,
  required String title,
}) async {
  await database.customStatement(
    'INSERT INTO bookmarks(url, title) VALUES (?, ?)',
    [url, title],
  );
  final id =
      (await database
              .customSelect(
                'SELECT id FROM bookmarks WHERE title = ? ORDER BY id DESC LIMIT 1',
                variables: [Variable<String>(title)],
              )
              .getSingle())
          .read<int>('id');
  await database.customStatement(
    'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
    [id, workspaceId],
  );
  return id;
}

Future<int> _bookmarkObjectId(
  AppDatabase database, {
  required int workspaceId,
  required int bookmarkId,
}) async =>
    (await database
            .customSelect(
              '''SELECT object_id FROM bookmark_object_links
         WHERE workspace_id = ? AND bookmark_id = ?''',
              variables: <Variable<Object>>[
                Variable<int>(workspaceId),
                Variable<int>(bookmarkId),
              ],
            )
            .getSingle())
        .read<int>('object_id');

Future<void> _attachLegacyTag(
  AppDatabase database, {
  required int bookmarkId,
  required int tagId,
}) => database.customStatement(
  'INSERT INTO bookmark_tags(bookmark_id, tag_id) VALUES (?, ?)',
  [bookmarkId, tagId],
);

Future<void> _expectNoCanonicalWeblinkTagsSchema(
  ObjectSyncService sync,
  int workspaceId,
) async {
  final weblinkType = await sync.systemObjectStore.getSystemObjectType(
    workspaceId: workspaceId,
    systemKey: WeblinkObjectService.systemKey,
  );
  expect(weblinkType, isNotNull);
  expect(
    weblinkType!.properties.where((property) => property.name == 'Tags'),
    isEmpty,
  );
}

Future<_CanonicalTagState> _canonicalState(
  ObjectSyncService sync,
  int workspaceId,
) async {
  final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
    workspaceId: workspaceId,
    systemKey: WeblinkObjectService.systemKey,
  ))!;
  final tags = weblinkType.properties.singleWhere(
    (property) => property.name == 'Tags',
  );
  final weblink = (await sync.objectStore.listObjects(weblinkType.id)).single;
  final tagIds = ObjectRelationValue.fromJson(weblink.values[tags.id])
      .objectIds;
  final edges = (await sync.objectStore.outgoingRelations(weblink.id))
      .where((edge) => edge.propertyId == tags.id)
      .toList(growable: false);
  return _CanonicalTagState(tagIds: tagIds, edges: edges);
}

class _CanonicalTagState {
  const _CanonicalTagState({required this.tagIds, required this.edges});

  final List<int> tagIds;
  final List<ObjectRelationEdge> edges;
}
