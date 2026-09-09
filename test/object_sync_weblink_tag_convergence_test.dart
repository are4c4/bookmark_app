import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production sync converges Tags and reports watcher-driven Weblink impact',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final firstTagId = await _createTag(database, 'First');
      final secondTagId = await _createTag(database, 'Second');
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/watched-tags',
        title: 'Watched tags',
      );
      await _attachLegacyTag(
        database,
        bookmarkId: bookmarkId,
        tagId: firstTagId,
      );

      final notifications = <List<int>>[];
      final sync = ObjectSyncService(
        database,
        onCanonicalObjectsMirrored: (objectIds) async {
          notifications.add(objectIds.toList(growable: false));
        },
      );
      addTearDown(sync.dispose);

      await sync.syncWorkspace(workspaceId);
      final initial = await _canonicalState(sync, workspaceId);
      final firstTagObjectId = await sync.tagBridge.objectIdForLegacyTag(
        workspaceId,
        firstTagId,
      );
      expect(firstTagObjectId, isNotNull);
      expect(initial.tagIds, <int>[firstTagObjectId!]);
      expect(notifications, isEmpty);

      notifications.clear();
      await (database.delete(
        database.bookmarkTags,
      )..where((row) => row.bookmarkId.equals(bookmarkId))).go();
      await database
          .into(database.bookmarkTags)
          .insert(
            BookmarkTagsCompanion.insert(
              bookmarkId: bookmarkId,
              tagId: secondTagId,
            ),
          );

      await _waitUntil(
        () => notifications.any(
          (objectIds) => objectIds.contains(initial.weblinkObjectId),
        ),
      );

      final secondTagObjectId = await sync.tagBridge.objectIdForLegacyTag(
        workspaceId,
        secondTagId,
      );
      expect(secondTagObjectId, isNotNull);
      final after = await _canonicalState(sync, workspaceId);
      expect(after.tagIds, <int>[secondTagObjectId!]);
      expect(after.edges.map((edge) => edge.targetObjectId).toList(), <int>[
        secondTagObjectId,
      ]);
      expect(
        notifications.any(
          (objectIds) => objectIds.contains(initial.weblinkObjectId),
        ),
        isTrue,
      );
    },
  );

  test(
    'canonical-only Weblink Tag edit survives compatibility resync',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final legacyTagId = await _createTag(database, 'Legacy');
      final canonicalTagId = await _createTag(database, 'Canonical');
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/canonical-tag',
        title: 'Canonical tag',
      );
      await _attachLegacyTag(
        database,
        bookmarkId: bookmarkId,
        tagId: legacyTagId,
      );

      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);
      await sync.syncWorkspace(workspaceId);

      final canonicalTagObjectId = await sync.tagBridge.objectIdForLegacyTag(
        workspaceId,
        canonicalTagId,
      );
      expect(canonicalTagObjectId, isNotNull);
      final state = await _canonicalState(sync, workspaceId);
      final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ))!;
      final tags = weblinkType.properties.singleWhere(
        (property) => property.name == 'Tags',
      );
      final genericStore = GenericDatabaseStore(database);
      final mutations = RelationMutationService(
        objectStore: sync.objectStore,
        genericStore: genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: sync.objectStore,
        ),
      );
      await mutations.setRelation(
        objectId: state.weblinkObjectId,
        property: tags,
        targetObjectIds: <int>[canonicalTagObjectId!],
      );

      await sync.syncWorkspace(workspaceId);

      final after = await _canonicalState(sync, workspaceId);
      expect(after.tagIds, <int>[canonicalTagObjectId]);
    },
  );

  test('invalid URL Bookmark does not enter Weblink Tag convergence', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final tagId = await _createTag(database, 'Invalid URL tag');
    final bookmarkId = await _createBookmark(
      database,
      workspaceId: workspaceId,
      url: 'not a valid url',
      title: 'Invalid URL',
    );
    await _attachLegacyTag(database, bookmarkId: bookmarkId, tagId: tagId);

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);

    final weblinkType = await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    expect(weblinkType, isNotNull);
    expect(
      weblinkType!.properties.where((property) => property.name == 'Tags'),
      isEmpty,
    );
  });
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for ObjectSync canonical impact.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

Future<int> _createTag(AppDatabase database, String name) async {
  await database.customStatement('INSERT INTO tags(name) VALUES (?)', <Object>[
    name,
  ]);
  return (await database
          .customSelect(
            'SELECT id FROM tags WHERE name = ?',
            variables: <Variable<Object>>[Variable<String>(name)],
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
    <Object>[url, title],
  );
  final bookmarkId =
      (await database
              .customSelect(
                'SELECT id FROM bookmarks WHERE title = ? ORDER BY id DESC LIMIT 1',
                variables: <Variable<Object>>[Variable<String>(title)],
              )
              .getSingle())
          .read<int>('id');
  await database.customStatement(
    'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
    <Object>[bookmarkId, workspaceId],
  );
  return bookmarkId;
}

Future<void> _attachLegacyTag(
  AppDatabase database, {
  required int bookmarkId,
  required int tagId,
}) => database
    .into(database.bookmarkTags)
    .insert(BookmarkTagsCompanion.insert(bookmarkId: bookmarkId, tagId: tagId));

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
  return _CanonicalTagState(
    weblinkObjectId: weblink.id,
    tagIds: tagIds,
    edges: edges,
  );
}

class _CanonicalTagState {
  const _CanonicalTagState({
    required this.weblinkObjectId,
    required this.tagIds,
    required this.edges,
  });

  final int weblinkObjectId;
  final List<int> tagIds;
  final List<ObjectRelationEdge> edges;
}
