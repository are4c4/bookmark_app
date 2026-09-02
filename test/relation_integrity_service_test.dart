import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<RelationIntegrityService> serviceFor(AppDatabase database) async {
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    return RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
  }

  test('healthy persisted relation reports no issues', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = await serviceFor(database);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(objectTypeId: bookTypeId, title: 'Book');
    final personId = await objectStore.createObject(objectTypeId: personTypeId, title: 'Person');
    await objectStore.setRelation(
      objectId: bookId,
      property: property,
      targetObjectIds: [personId],
    );

    expect((await service.auditWorkspace(workspaceId)).isHealthy, isTrue);
  });

  test('audit detects missing normalized index edge without mutating values', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = await serviceFor(database);

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(objectTypeId: bookTypeId, title: 'Book');
    final personId = await objectStore.createObject(objectTypeId: personTypeId, title: 'Person');
    await objectStore.setRelation(objectId: bookId, property: property, targetObjectIds: [personId]);
    await database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      [bookId, property.id],
    );

    final report = await service.auditWorkspace(workspaceId);
    expect(report.issuesOf(RelationIntegrityIssueKind.missingIndexEdge), hasLength(1));
    final stored = (await objectStore.listObjects(bookTypeId)).single;
    expect(ObjectRelationValue.fromJson(stored.values[property.id]).objectIds, [personId]);
  });

  test('audit detects missing target object stored in legacy relation value', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = await serviceFor(database);

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(objectTypeId: bookTypeId, title: 'Book');
    await genericStore.setValue(
      recordId: bookId,
      propertyId: property.id,
      value: const {'objectIds': [999999]},
    );

    final report = await service.auditWorkspace(workspaceId);
    expect(report.issuesOf(RelationIntegrityIssueKind.missingTargetObject), hasLength(1));
    expect(report.issuesOf(RelationIntegrityIssueKind.missingIndexEdge), hasLength(1));
  });

  test('audit detects broken bidirectional pair metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    );

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final inverse = (await genericStore.listProperties(personTypeId))
        .singleWhere((property) => property.id == pair.inverseProperty.id);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: inverse.id,
        databaseId: inverse.databaseId,
        name: inverse.name,
        type: inverse.type,
        config: <String, dynamic>{...inverse.config, 'bidirectional': false},
        sortOrder: inverse.sortOrder,
      ),
    );

    final report = await service.auditWorkspace(workspaceId);
    expect(
      report.issuesOf(RelationIntegrityIssueKind.invalidBidirectionalPair),
      isNotEmpty,
    );
  });

  test('audit detects bidirectional inverse value mismatch', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    );

    final bookTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await objectStore.createObjectType(workspaceId: workspaceId, name: 'Person');
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Author',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final bookId = await objectStore.createObject(objectTypeId: bookTypeId, title: 'Book');
    final personId = await objectStore.createObject(objectTypeId: personTypeId, title: 'Person');
    await objectStore.setRelation(
      objectId: bookId,
      property: pair.sourceProperty,
      targetObjectIds: [personId],
    );
    await genericStore.setValue(
      recordId: personId,
      propertyId: pair.inverseProperty.id,
      value: const {'objectIds': []},
    );

    final report = await service.auditWorkspace(workspaceId);
    expect(report.issuesOf(RelationIntegrityIssueKind.inverseValueMismatch), hasLength(1));
  });

  test('audit detects cross-workspace target metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaces = WorkspaceStore(database);
    final workspaceA = await workspaces.initialize();
    final workspaceB = await workspaces.createWorkspace('Other');
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = await serviceFor(database);

    final sourceTypeId = await objectStore.createObjectType(workspaceId: workspaceA, name: 'Source');
    final targetTypeId = await objectStore.createObjectType(workspaceId: workspaceB, name: 'Target');
    final propertyId = await genericStore.createProperty(
      databaseId: sourceTypeId,
      name: 'Broken',
      type: 'relation',
      config: {'targetObjectTypeId': targetTypeId, 'multiple': true},
    );
    final raw = (await genericStore.listProperties(sourceTypeId))
        .singleWhere((property) => property.id == propertyId);
    expect(jsonEncode(raw.config), contains('$targetTypeId'));

    final report = await service.auditWorkspace(workspaceA);
    expect(report.issuesOf(RelationIntegrityIssueKind.crossWorkspaceTarget), hasLength(1));
  });
}
