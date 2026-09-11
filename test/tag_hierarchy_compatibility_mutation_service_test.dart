import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_group_store.dart';
import 'package:bookmark_app/data/tag_hierarchy_compatibility_mutation_service.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'move and restore keep canonical and legacy hierarchy equivalent',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final firstGroupId = await fixture.legacy.createGroup('First');
      final secondGroupId = await fixture.legacy.createGroup('Second');
      final parentId = await fixture.createLegacyTag('parent');
      final movingId = await fixture.createLegacyTag('moving');
      final childId = await fixture.createLegacyTag('child');
      await fixture.legacy.moveTag(tagId: parentId, groupId: secondGroupId);
      await fixture.legacy.moveTag(tagId: movingId, groupId: firstGroupId);
      await fixture.legacy.moveTag(
        tagId: childId,
        parentTagId: movingId,
        groupId: firstGroupId,
      );
      await fixture.sync();

      final snapshot = await fixture.service.moveTag(
        workspaceId: fixture.workspaceId,
        tagId: movingId,
        parentTagId: parentId,
        groupId: firstGroupId,
      );

      expect(snapshot.previousParentTagId, isNull);
      expect(snapshot.previousGroupIds, <int, int?>{
        movingId: firstGroupId,
        childId: firstGroupId,
      });
      expect(snapshot.appliedGroupId, secondGroupId);
      expect(await fixture.legacyParentId(movingId), parentId);
      expect(await fixture.legacyGroupId(movingId), secondGroupId);
      expect(await fixture.legacyGroupId(childId), secondGroupId);
      expect(await fixture.canonicalParentLegacyId(movingId), parentId);
      expect(await fixture.canonicalGroupLegacyId(movingId), secondGroupId);
      expect(await fixture.canonicalGroupLegacyId(childId), secondGroupId);

      await fixture.service.restoreMove(
        workspaceId: fixture.workspaceId,
        snapshot: snapshot,
      );

      expect(await fixture.legacyParentId(movingId), isNull);
      expect(await fixture.legacyGroupId(movingId), firstGroupId);
      expect(await fixture.legacyGroupId(childId), firstGroupId);
      expect(await fixture.canonicalParentLegacyId(movingId), isNull);
      expect(await fixture.canonicalGroupLegacyId(movingId), firstGroupId);
      expect(await fixture.canonicalGroupLegacyId(childId), firstGroupId);
    },
  );

  test(
    'explicit compatibility move can follow a canonical-only Group edit',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final firstGroupId = await fixture.legacy.createGroup('First');
      final secondGroupId = await fixture.legacy.createGroup('Second');
      final tagId = await fixture.createLegacyTag('tag');
      await fixture.legacy.moveTag(tagId: tagId, groupId: firstGroupId);
      await fixture.sync();

      final tagObjectId = await fixture.tagObjectId(tagId);
      final secondGroupObjectId = await fixture.groupObjectId(secondGroupId);
      await fixture.bridge.hierarchyIntegrity.setGroup(
        workspaceId: fixture.workspaceId,
        tagObjectId: tagObjectId,
        groupProperty: fixture.schema.groupProperty,
        tagGroupObjectId: secondGroupObjectId,
      );
      await fixture.bridge.syncLegacyTags(fixture.workspaceId);
      expect(await fixture.legacyGroupId(tagId), firstGroupId);
      expect(await fixture.canonicalGroupLegacyId(tagId), secondGroupId);

      final snapshot = await fixture.service.moveTag(
        workspaceId: fixture.workspaceId,
        tagId: tagId,
        groupId: firstGroupId,
      );

      expect(snapshot.previousGroupIds[tagId], secondGroupId);
      expect(await fixture.legacyGroupId(tagId), firstGroupId);
      expect(await fixture.canonicalGroupLegacyId(tagId), firstGroupId);
    },
  );

  test('cycle failure rolls back canonical and legacy state', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final groupId = await fixture.legacy.createGroup('Group');
    final rootId = await fixture.createLegacyTag('root');
    final childId = await fixture.createLegacyTag('child');
    await fixture.legacy.moveTag(tagId: rootId, groupId: groupId);
    await fixture.legacy.moveTag(
      tagId: childId,
      parentTagId: rootId,
      groupId: groupId,
    );
    await fixture.sync();

    await expectLater(
      fixture.service.moveTag(
        workspaceId: fixture.workspaceId,
        tagId: rootId,
        parentTagId: childId,
        groupId: groupId,
      ),
      throwsStateError,
    );

    expect(await fixture.legacyParentId(rootId), isNull);
    expect(await fixture.legacyParentId(childId), rootId);
    expect(await fixture.canonicalParentLegacyId(rootId), isNull);
    expect(await fixture.canonicalParentLegacyId(childId), rootId);
    expect(await fixture.legacyGroupId(rootId), groupId);
    expect(await fixture.canonicalGroupLegacyId(rootId), groupId);
  });

  test(
    'malformed canonical Parent fails without compatibility mutation',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final groupId = await fixture.legacy.createGroup('Group');
      final tagId = await fixture.createLegacyTag('tag');
      await fixture.legacy.moveTag(tagId: tagId, groupId: groupId);
      await fixture.sync();
      final objectId = await fixture.tagObjectId(tagId);
      await fixture.genericStore.setValue(
        recordId: objectId,
        propertyId: fixture.schema.parentProperty.id,
        value: 'malformed',
      );

      await expectLater(
        fixture.service.moveTag(
          workspaceId: fixture.workspaceId,
          tagId: tagId,
          groupId: null,
        ),
        throwsStateError,
      );

      expect(await fixture.legacyParentId(tagId), isNull);
      expect(await fixture.legacyGroupId(tagId), groupId);
      final object = await fixture.tagObject(tagId);
      expect(object.values[fixture.schema.parentProperty.id], 'malformed');
    },
  );

  test(
    'wrong-target canonical Parent fails without compatibility mutation',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final groupId = await fixture.legacy.createGroup('Group');
      final tagId = await fixture.createLegacyTag('tag');
      await fixture.legacy.moveTag(tagId: tagId, groupId: groupId);
      await fixture.sync();

      final tagObjectId = await fixture.tagObjectId(tagId);
      final groupObjectId = await fixture.groupObjectId(groupId);
      await fixture.genericStore.setValue(
        recordId: tagObjectId,
        propertyId: fixture.schema.parentProperty.id,
        value: <int>[groupObjectId],
      );
      await fixture.database.customStatement(
        '''INSERT INTO object_relation_edges(
             source_object_id, property_id, target_object_id, position
           ) VALUES (?, ?, ?, ?)''',
        <Object?>[
          tagObjectId,
          fixture.schema.parentProperty.id,
          groupObjectId,
          0,
        ],
      );

      await expectLater(
        fixture.service.moveTag(
          workspaceId: fixture.workspaceId,
          tagId: tagId,
          groupId: null,
        ),
        throwsStateError,
      );

      expect(await fixture.legacyParentId(tagId), isNull);
      expect(await fixture.legacyGroupId(tagId), groupId);
      final object = await fixture.tagObject(tagId);
      expect(object.values[fixture.schema.parentProperty.id], <int>[
        groupObjectId,
      ]);
      final edges = (await fixture.objectStore.outgoingRelations(tagObjectId))
          .where((edge) => edge.propertyId == fixture.schema.parentProperty.id)
          .toList(growable: false);
      expect(edges, hasLength(1));
      expect(edges.single.targetObjectId, groupObjectId);
    },
  );

  test(
    'wrong-target canonical Group fails without compatibility mutation',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final groupId = await fixture.legacy.createGroup('Group');
      final tagId = await fixture.createLegacyTag('tag');
      final wrongTagId = await fixture.createLegacyTag('wrong-target');
      await fixture.legacy.moveTag(tagId: tagId, groupId: groupId);
      await fixture.sync();

      final tagObjectId = await fixture.tagObjectId(tagId);
      final wrongTagObjectId = await fixture.tagObjectId(wrongTagId);
      await fixture.genericStore.setValue(
        recordId: tagObjectId,
        propertyId: fixture.schema.groupProperty.id,
        value: <int>[wrongTagObjectId],
      );
      await fixture.database.customStatement(
        'DELETE FROM object_relation_edges '
        'WHERE source_object_id = ? AND property_id = ?',
        <Object?>[tagObjectId, fixture.schema.groupProperty.id],
      );
      await fixture.database.customStatement(
        '''INSERT INTO object_relation_edges(
             source_object_id, property_id, target_object_id, position
           ) VALUES (?, ?, ?, ?)''',
        <Object?>[
          tagObjectId,
          fixture.schema.groupProperty.id,
          wrongTagObjectId,
          0,
        ],
      );

      await expectLater(
        fixture.service.moveTag(
          workspaceId: fixture.workspaceId,
          tagId: tagId,
          groupId: null,
        ),
        throwsStateError,
      );

      expect(await fixture.legacyParentId(tagId), isNull);
      expect(await fixture.legacyGroupId(tagId), groupId);
      final object = await fixture.tagObject(tagId);
      expect(object.values[fixture.schema.groupProperty.id], <int>[
        wrongTagObjectId,
      ]);
      final edges = (await fixture.objectStore.outgoingRelations(tagObjectId))
          .where((edge) => edge.propertyId == fixture.schema.groupProperty.id)
          .toList(growable: false);
      expect(edges, hasLength(1));
      expect(edges.single.targetObjectId, wrongTagObjectId);
    },
  );

  test(
    'restore rejects later canonical edit without overwriting either side',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final firstGroupId = await fixture.legacy.createGroup('First');
      final secondGroupId = await fixture.legacy.createGroup('Second');
      final tagId = await fixture.createLegacyTag('tag');
      await fixture.legacy.moveTag(tagId: tagId, groupId: firstGroupId);
      await fixture.sync();

      final snapshot = await fixture.service.moveTag(
        workspaceId: fixture.workspaceId,
        tagId: tagId,
        groupId: secondGroupId,
      );
      final tagObjectId = await fixture.tagObjectId(tagId);
      final firstGroupObjectId = await fixture.groupObjectId(firstGroupId);
      await fixture.bridge.hierarchyIntegrity.setGroup(
        workspaceId: fixture.workspaceId,
        tagObjectId: tagObjectId,
        groupProperty: fixture.schema.groupProperty,
        tagGroupObjectId: firstGroupObjectId,
      );

      await expectLater(
        fixture.service.restoreMove(
          workspaceId: fixture.workspaceId,
          snapshot: snapshot,
        ),
        throwsStateError,
      );

      expect(await fixture.legacyGroupId(tagId), secondGroupId);
      expect(await fixture.canonicalGroupLegacyId(tagId), firstGroupId);
    },
  );

  test('repeating the same compatibility move is idempotent', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final groupId = await fixture.legacy.createGroup('Group');
    final tagId = await fixture.createLegacyTag('tag');
    await fixture.sync();

    await fixture.service.moveTag(
      workspaceId: fixture.workspaceId,
      tagId: tagId,
      groupId: groupId,
    );
    await fixture.service.moveTag(
      workspaceId: fixture.workspaceId,
      tagId: tagId,
      groupId: groupId,
    );

    expect(await fixture.legacyGroupId(tagId), groupId);
    expect(await fixture.canonicalGroupLegacyId(tagId), groupId);
  });
}

Future<_Fixture> _fixture() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final workspaceId = await WorkspaceStore(database).initialize();
  final genericStore = GenericDatabaseStore(database);
  final objectStore = ObjectStore(genericStore);
  final systemStore = SystemObjectStore(
    database: database,
    objectStore: objectStore,
  );
  final bridge = TagObjectBridge(
    database: database,
    objectStore: objectStore,
    systemObjectStore: systemStore,
  );
  final schema = await bridge.ensureTagObjectType(workspaceId);
  final legacy = TagGroupStore(database);
  return _Fixture(
    database: database,
    workspaceId: workspaceId,
    genericStore: genericStore,
    objectStore: objectStore,
    bridge: bridge,
    schema: schema,
    legacy: legacy,
    service: TagHierarchyCompatibilityMutationService(
      database: database,
      objectStore: objectStore,
      bridge: bridge,
    ),
  );
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.bridge,
    required this.schema,
    required this.legacy,
    required this.service,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final TagObjectBridge bridge;
  final TagObjectSchema schema;
  final TagGroupStore legacy;
  final TagHierarchyCompatibilityMutationService service;

  Future<int> createLegacyTag(String name) => database.createTag(name);

  Future<void> sync() => bridge.syncLegacyTags(workspaceId);

  Future<int> tagObjectId(int legacyTagId) async {
    final id = await bridge.objectIdForLegacyTag(workspaceId, legacyTagId);
    if (id == null) throw StateError('Missing canonical Tag Object.');
    return id;
  }

  Future<int> groupObjectId(int legacyGroupId) async {
    final id = await bridge.objectIdForLegacyTagGroup(
      workspaceId,
      legacyGroupId,
    );
    if (id == null) throw StateError('Missing canonical TagGroup Object.');
    return id;
  }

  Future<AppObject> tagObject(int legacyTagId) async {
    final id = await tagObjectId(legacyTagId);
    final objects = await objectStore.listObjects(schema.objectType.id);
    return objects.singleWhere((object) => object.id == id);
  }

  Future<int?> canonicalParentLegacyId(int legacyTagId) async {
    final objectId = await tagObjectId(legacyTagId);
    final selection = await bridge.hierarchyIntegrity.relationTargets
        .selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: objectId,
          property: schema.parentProperty,
        );
    if (selection.selectedObjectIds.isEmpty) return null;
    final targetId = selection.selectedObjectIds.single;
    return bridge.legacyTagIdForObject(workspaceId, targetId);
  }

  Future<int?> canonicalGroupLegacyId(int legacyTagId) async {
    final objectId = await tagObjectId(legacyTagId);
    final selection = await bridge.hierarchyIntegrity.relationTargets
        .selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: objectId,
          property: schema.groupProperty,
        );
    if (selection.selectedObjectIds.isEmpty) return null;
    final groupObjectId = selection.selectedObjectIds.single;
    final groupObjects = await objectStore.listObjects(
      schema.tagGroupObjectType.id,
    );
    final groupObject = groupObjects.singleWhere(
      (object) => object.id == groupObjectId,
    );
    final raw = groupObject.values[schema.legacyTagGroupIdProperty.id];
    return raw is int ? raw : int.tryParse('$raw');
  }

  Future<int?> legacyParentId(int legacyTagId) async {
    final row = await (database.select(
      database.tags,
    )..where((tag) => tag.id.equals(legacyTagId))).getSingle();
    return row.parentTagId;
  }

  Future<int?> legacyGroupId(int legacyTagId) async {
    final row = await (database.select(
      database.tags,
    )..where((tag) => tag.id.equals(legacyTagId))).getSingle();
    return row.groupId;
  }
}
