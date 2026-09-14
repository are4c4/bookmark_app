import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_health_audit.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late ObjectHealthAudit audit;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    audit = ObjectHealthAudit(genericStore);
    workspaceId = await WorkspaceStore(database).initialize();
  });

  tearDown(() => database.close());

  test('healthy A-owned value state reports no findings', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Notes',
      type: ObjectPropertyType.text,
    );
    final property = (await objectStore.getObjectType(typeId))!.properties
        .singleWhere((item) => item.id == propertyId);
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Book',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: 'healthy',
    );

    expect((await audit.auditWorkspace(workspaceId)).isHealthy, isTrue);
  });

  test(
    'detects a value attached through another ObjectType Property',
    () async {
      final bookTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Book',
      );
      final personTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Person',
      );
      final personPropertyId = await objectStore.createProperty(
        objectTypeId: personTypeId,
        name: 'Role',
        type: ObjectPropertyType.text,
      );
      final bookId = await objectStore.createObject(
        objectTypeId: bookTypeId,
        title: 'Book',
      );

      // Canonical writes reject this mismatch. Insert the corrupt persisted row
      // directly so the audit regression exercises legacy/corrupt state only.
      await database.customStatement(
        'INSERT INTO generic_values (record_id, property_id, value_json) '
        'VALUES (?, ?, ?)',
        [bookId, personPropertyId, '"invalid attachment"'],
      );

      final result = await audit.auditWorkspace(workspaceId);
      final finding = result
          .issuesOf(ObjectHealthIssueKind.crossObjectTypeValue)
          .single;
      expect(finding.objectId, bookId);
      expect(finding.objectTypeId, bookTypeId);
      expect(finding.propertyId, personPropertyId);
      expect(finding.propertyObjectTypeId, personTypeId);
    },
  );

  test('detects a directly persisted computed Property value', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Computed',
      type: ObjectPropertyType.formula,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Book',
    );

    await genericStore.setValue(
      recordId: objectId,
      propertyId: propertyId,
      value: 42,
    );

    final result = await audit.auditWorkspace(workspaceId);
    expect(
      result.issuesOf(ObjectHealthIssueKind.computedPropertyHasStoredValue),
      hasLength(1),
    );
  });

  test('detects malformed JSON without exposing persisted content', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Notes',
      type: ObjectPropertyType.text,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Book',
    );
    await genericStore.setValue(
      recordId: objectId,
      propertyId: propertyId,
      value: 'before corruption',
    );
    await database.customStatement(
      'UPDATE generic_values SET value_json = ? '
      'WHERE record_id = ? AND property_id = ?',
      ['{private malformed payload', objectId, propertyId],
    );

    final result = await audit.auditWorkspace(workspaceId);
    final finding = result
        .issuesOf(ObjectHealthIssueKind.malformedValueJson)
        .single;
    expect(finding.objectId, objectId);
    expect(finding.propertyId, propertyId);
    expect(finding.toString(), isNot(contains('private malformed payload')));
  });

  test('does not duplicate B-owned Relation payload validation', () async {
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    await genericStore.setValue(
      recordId: bookId,
      propertyId: propertyId,
      value: const <String, dynamic>{'objectIds': <int>[]},
    );
    await database.customStatement(
      'UPDATE generic_values SET value_json = ? '
      'WHERE record_id = ? AND property_id = ?',
      ['{relation payload belongs to B', bookId, propertyId],
    );

    expect((await audit.auditWorkspace(workspaceId)).isHealthy, isTrue);
  });
}
