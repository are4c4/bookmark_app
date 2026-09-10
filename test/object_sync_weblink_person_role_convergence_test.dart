import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_weblink_person_role_convergence_service.dart';
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
    'production sync preserves multiple normalized Person roles on Weblink',
    () async {
      final fixture = await _RoleFixture.create();
      addTearDown(fixture.dispose);
      final aliceId = await fixture.createPerson('Alice');
      final bobId = await fixture.createPerson('Bob');
      final bookmarkId = await fixture.createBookmark(
        url: 'https://example.com/roles',
        title: 'Roles',
      );
      await fixture.setLegacyRole(bookmarkId, aliceId, '著者');
      await fixture.setLegacyRole(bookmarkId, aliceId, '編集者');
      await fixture.setLegacyRole(bookmarkId, bobId, '著者');
      await fixture.setLegacyRole(bookmarkId, bobId, 'performer');

      await fixture.sync.syncWorkspace(fixture.workspaceId);

      final state = await fixture.roleState();
      final aliceObjectId = await fixture.personObjectId(aliceId);
      final bobObjectId = await fixture.personObjectId(bobId);
      expect(state['著者'], <int>[aliceObjectId, bobObjectId]);
      expect(state['編集者'], <int>[aliceObjectId]);
      expect(state['出演者'], <int>[bobObjectId]);

      final authorProperty = await fixture.targetRoleProperty('著者');
      final outgoing = await fixture.sync.objectStore.outgoingRelations(
        fixture.weblinkObjectId,
      );
      expect(
        outgoing
            .where((edge) => edge.propertyId == authorProperty.id)
            .map((edge) => edge.targetObjectId)
            .toList(),
        <int>[aliceObjectId, bobObjectId],
      );
    },
  );

  test(
    'legacy-only role changes advance while canonical-only edits survive',
    () async {
      final fixture = await _RoleFixture.create();
      addTearDown(fixture.dispose);
      final aliceId = await fixture.createPerson('Alice');
      final bobId = await fixture.createPerson('Bob');
      final bookmarkId = await fixture.createBookmark(
        url: 'https://example.com/role-three-way',
        title: 'Role three way',
      );
      await fixture.setLegacyRole(bookmarkId, aliceId, '著者');
      await fixture.sync.syncWorkspace(fixture.workspaceId);

      final aliceObjectId = await fixture.personObjectId(aliceId);
      final bobObjectId = await fixture.personObjectId(bobId);
      final authorProperty = await fixture.targetRoleProperty('著者');
      expect((await fixture.roleState())['著者'], <int>[aliceObjectId]);

      await fixture.clearLegacyRole(bookmarkId, '著者');
      await fixture.setLegacyRole(bookmarkId, bobId, '著者');
      await fixture.sync.syncWorkspace(fixture.workspaceId);
      expect((await fixture.roleState())['著者'], <int>[bobObjectId]);

      await fixture.mutations.setRelation(
        objectId: fixture.weblinkObjectId,
        property: authorProperty,
        targetObjectIds: <int>[aliceObjectId],
      );
      await fixture.sync.syncWorkspace(fixture.workspaceId);
      expect((await fixture.roleState())['著者'], <int>[aliceObjectId]);
    },
  );

  test(
    'conflicting Bookmarks for one Weblink fail without managed target roles',
    () async {
      final fixture = await _RoleFixture.create();
      addTearDown(fixture.dispose);
      final aliceId = await fixture.createPerson('Alice');
      final bobId = await fixture.createPerson('Bob');
      final firstBookmarkId = await fixture.createBookmark(
        url: 'https://example.com/shared-role',
        title: 'Shared role A',
      );
      final secondBookmarkId = await fixture.createBookmark(
        url: 'https://example.com/shared-role',
        title: 'Shared role B',
      );
      await fixture.setLegacyRole(firstBookmarkId, aliceId, '著者');
      await fixture.setLegacyRole(secondBookmarkId, bobId, '著者');

      await expectLater(
        fixture.sync.syncWorkspace(fixture.workspaceId),
        throwsA(isA<StateError>()),
      );

      final weblinkType = await fixture.sync.systemObjectStore
          .getSystemObjectType(
            workspaceId: fixture.workspaceId,
            systemKey: WeblinkObjectService.systemKey,
          );
      expect(weblinkType, isNotNull);
      expect(
        weblinkType!.properties.where(
          (property) =>
              property.config[BookmarkWeblinkPersonRoleConvergenceService
                  .roleContractMetadataKey] ==
              BookmarkWeblinkPersonRoleConvergenceService.targetRoleContract,
        ),
        isEmpty,
      );
    },
  );

  test(
    'equivalent Bookmarks sharing one Weblink converge idempotently',
    () async {
      final fixture = await _RoleFixture.create();
      addTearDown(fixture.dispose);
      final aliceId = await fixture.createPerson('Alice');
      final firstBookmarkId = await fixture.createBookmark(
        url: 'https://example.com/equivalent-role',
        title: 'Equivalent role A',
      );
      final secondBookmarkId = await fixture.createBookmark(
        url: 'https://example.com/equivalent-role',
        title: 'Equivalent role B',
      );
      await fixture.setLegacyRole(firstBookmarkId, aliceId, '著者');
      await fixture.setLegacyRole(secondBookmarkId, aliceId, '著者');

      await fixture.sync.syncWorkspace(fixture.workspaceId);
      final firstState = await fixture.roleState();
      await fixture.sync.syncWorkspace(fixture.workspaceId);
      final secondState = await fixture.roleState();

      expect(secondState, firstState);
      expect(firstState['著者'], <int>[await fixture.personObjectId(aliceId)]);
      expect((await fixture.weblinks()).length, 1);
    },
  );

  test(
    'managed role metadata avoids unrelated same-name Weblink Property',
    () async {
      final fixture = await _RoleFixture.create();
      addTearDown(fixture.dispose);
      final aliceId = await fixture.createPerson('Alice');
      final bookmarkId = await fixture.createBookmark(
        url: 'https://example.com/role-name-collision',
        title: 'Role name collision',
      );
      await fixture.sync.syncWorkspace(fixture.workspaceId);

      final weblinkType = (await fixture.sync.systemObjectStore
          .getSystemObjectType(
            workspaceId: fixture.workspaceId,
            systemKey: WeblinkObjectService.systemKey,
          ))!;
      final unrelatedId = await fixture.sync.objectStore.createProperty(
        objectTypeId: weblinkType.id,
        name: '著者',
        type: ObjectPropertyType.text,
        allowSystemMutation: true,
      );
      await fixture.setLegacyRole(bookmarkId, aliceId, '著者');
      await fixture.sync.syncWorkspace(fixture.workspaceId);

      final refreshed = (await fixture.sync.objectStore.getObjectType(
        weblinkType.id,
      ))!;
      final unrelated = refreshed.properties.singleWhere(
        (property) => property.id == unrelatedId,
      );
      final managed = await fixture.targetRoleProperty('著者');
      expect(unrelated.type, ObjectPropertyType.text);
      expect(managed.id, isNot(unrelated.id));
      expect(managed.name, '著者 (人物)');
      expect(
        managed.config[BookmarkWeblinkPersonRoleConvergenceService
            .roleMetadataKey],
        '著者',
      );
    },
  );

  test(
    'source Relation index drift fails before compatibility repair',
    () async {
      final fixture = await _RoleFixture.create();
      addTearDown(fixture.dispose);
      final aliceId = await fixture.createPerson('Alice');
      final bookmarkId = await fixture.createBookmark(
        url: 'https://example.com/source-drift-role',
        title: 'Source drift role',
      );
      await fixture.setLegacyRole(bookmarkId, aliceId, '著者');
      await fixture.sync.syncWorkspace(fixture.workspaceId);

      final sourceProperty = await fixture.sourceRoleProperty('著者');
      final bookmarkObjectId = await fixture.bookmarkObjectId(bookmarkId);
      await fixture.database.customStatement(
        'DELETE FROM object_relation_edges '
        'WHERE source_object_id = ? AND property_id = ?',
        <Object>[bookmarkObjectId, sourceProperty.id],
      );

      await expectLater(
        fixture.sync.syncWorkspace(fixture.workspaceId),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('target Relation index drift fails without overwriting value', () async {
    final fixture = await _RoleFixture.create();
    addTearDown(fixture.dispose);
    final aliceId = await fixture.createPerson('Alice');
    final bookmarkId = await fixture.createBookmark(
      url: 'https://example.com/target-drift-role',
      title: 'Target drift role',
    );
    await fixture.setLegacyRole(bookmarkId, aliceId, '著者');
    await fixture.sync.syncWorkspace(fixture.workspaceId);

    final targetProperty = await fixture.targetRoleProperty('著者');
    final before = (await fixture.roleState())['著者'];
    await fixture.database.customStatement(
      'DELETE FROM object_relation_edges '
      'WHERE source_object_id = ? AND property_id = ?',
      <Object>[fixture.weblinkObjectId, targetProperty.id],
    );

    await expectLater(
      fixture.sync.syncWorkspace(fixture.workspaceId),
      throwsA(isA<StateError>()),
    );
    final weblink = (await fixture.weblinks()).single;
    expect(
      ObjectRelationValue.fromJson(weblink.values[targetProperty.id]).objectIds,
      before,
    );
  });

  test(
    'watcher-driven legacy role change reports exact Weblink impact',
    () async {
      final notifications = <List<int>>[];
      final fixture = await _RoleFixture.create(
        onCanonicalObjectsMirrored: (objectIds) async {
          notifications.add(objectIds.toList(growable: false));
        },
      );
      addTearDown(fixture.dispose);
      final aliceId = await fixture.createPerson('Alice');
      final bobId = await fixture.createPerson('Bob');
      final bookmarkId = await fixture.createBookmark(
        url: 'https://example.com/watched-role',
        title: 'Watched role',
      );
      await fixture.setLegacyRole(bookmarkId, aliceId, '著者');
      await fixture.sync.syncWorkspace(fixture.workspaceId);
      final weblinkObjectId = (await fixture.weblinks()).single.id;
      notifications.clear();

      await fixture.clearLegacyRole(bookmarkId, '著者');
      await fixture.setLegacyRole(bookmarkId, bobId, '著者');
      await _waitUntil(
        () => notifications.any((ids) => ids.contains(weblinkObjectId)),
      );

      expect((await fixture.roleState())['著者'], <int>[
        await fixture.personObjectId(bobId),
      ]);
      expect(notifications.any((ids) => ids.contains(weblinkObjectId)), isTrue);
    },
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for Weblink Person-role sync impact.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

class _RoleFixture {
  _RoleFixture({
    required this.database,
    required this.workspaceId,
    required this.sync,
  });

  static Future<_RoleFixture> create({
    Future<void> Function(Iterable<int> objectIds)? onCanonicalObjectsMirrored,
  }) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(
      database,
      onCanonicalObjectsMirrored: onCanonicalObjectsMirrored,
    );
    return _RoleFixture(
      database: database,
      workspaceId: workspaceId,
      sync: sync,
    );
  }

  final AppDatabase database;
  final int workspaceId;
  final ObjectSyncService sync;

  late final GenericDatabaseStore genericStore = GenericDatabaseStore(database);
  late final RelationMutationService mutations = RelationMutationService(
    objectStore: sync.objectStore,
    genericStore: genericStore,
    bidirectionalStore: BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: sync.objectStore,
    ),
  );

  int get weblinkObjectId => _cachedWeblinkObjectId!;
  int? _cachedWeblinkObjectId;

  Future<void> dispose() async {
    await sync.dispose();
    await database.close();
  }

  Future<int> createPerson(String name) async {
    await database.customStatement(
      'INSERT INTO people(name) VALUES (?)',
      <Object>[name],
    );
    return (await database
            .customSelect(
              'SELECT id FROM people WHERE name = ? ORDER BY id DESC LIMIT 1',
              variables: <Variable<Object>>[Variable<String>(name)],
            )
            .getSingle())
        .read<int>('id');
  }

  Future<int> createBookmark({
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

  Future<void> setLegacyRole(int bookmarkId, int personId, String role) =>
      database.customStatement(
        'INSERT INTO bookmark_people(bookmark_id, person_id, role) '
        'VALUES (?, ?, ?)',
        <Object>[bookmarkId, personId, role],
      );

  Future<void> clearLegacyRole(int bookmarkId, String role) =>
      database.customStatement(
        'DELETE FROM bookmark_people WHERE bookmark_id = ? AND role = ?',
        <Object>[bookmarkId, role],
      );

  Future<int> personObjectId(int legacyPersonId) async {
    final objectId = await sync.personBridge.objectIdForLegacyPerson(
      workspaceId,
      legacyPersonId,
    );
    expect(objectId, isNotNull);
    return objectId!;
  }

  Future<int> bookmarkObjectId(int legacyBookmarkId) async {
    return (await database
            .customSelect(
              '''SELECT object_id FROM bookmark_object_links
         WHERE workspace_id = ? AND bookmark_id = ?''',
              variables: <Variable<Object>>[
                Variable<int>(workspaceId),
                Variable<int>(legacyBookmarkId),
              ],
            )
            .getSingle())
        .read<int>('object_id');
  }

  Future<List<AppObject>> weblinks() async {
    final type = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    final objects = await sync.objectStore.listObjects(type.id);
    if (objects.length == 1) _cachedWeblinkObjectId = objects.single.id;
    return objects;
  }

  Future<ObjectPropertyDefinition> targetRoleProperty(String role) async {
    final type = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    return type.properties.singleWhere(
      (property) =>
          property.config[BookmarkWeblinkPersonRoleConvergenceService
                  .roleContractMetadataKey] ==
              BookmarkWeblinkPersonRoleConvergenceService.targetRoleContract &&
          property.config[BookmarkWeblinkPersonRoleConvergenceService
                  .roleMetadataKey] ==
              role,
    );
  }

  Future<ObjectPropertyDefinition> sourceRoleProperty(String role) async {
    final type = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: BookmarkWeblinkPersonRoleConvergenceService.bookmarkSystemKey,
    ))!;
    return type.properties.singleWhere(
      (property) =>
          property.config[BookmarkWeblinkPersonRoleConvergenceService
                  .roleContractMetadataKey] ==
              BookmarkWeblinkPersonRoleConvergenceService.sourceRoleContract &&
          property.config[BookmarkWeblinkPersonRoleConvergenceService
                  .roleMetadataKey] ==
              role,
    );
  }

  Future<Map<String, List<int>>> roleState() async {
    final objects = await weblinks();
    expect(objects, hasLength(1));
    final object = objects.single;
    final type = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    final result = <String, List<int>>{};
    for (final property in type.properties) {
      if (property.config[BookmarkWeblinkPersonRoleConvergenceService
              .roleContractMetadataKey] !=
          BookmarkWeblinkPersonRoleConvergenceService.targetRoleContract) {
        continue;
      }
      final role = property
          .config[BookmarkWeblinkPersonRoleConvergenceService.roleMetadataKey];
      if (role is! String) continue;
      result[role] = ObjectRelationValue.fromJson(object.values[property.id])
          .objectIds;
    }
    return result;
  }
}
