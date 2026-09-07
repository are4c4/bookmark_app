import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_property_deletion_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary Property deletion prunes ObjectType defaults atomically', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final deletion = ObjectPropertyDeletionService(
      genericStore: genericStore,
      objectStore: objectStore,
      defaultsStore: defaultsStore,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Article',
    );
    final keepId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Keep',
      type: ObjectPropertyType.text,
    );
    final deleteId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Delete',
      type: ObjectPropertyType.number,
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[deleteId, keepId],
        propertyOrder: <int>[keepId, deleteId],
        openMode: ObjectOpenMode.fullPage,
        bodyTemplate: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'notes',
              type: 'paragraph',
              text: 'Template notes',
            ),
          ],
        ),
      ),
    );
    final property = (await objectStore.getObjectType(typeId))!
        .properties
        .singleWhere((candidate) => candidate.id == deleteId);

    await deletion.deleteProperty(property);

    final type = (await objectStore.getObjectType(typeId))!;
    expect(type.properties.map((property) => property.id), <int>[keepId]);
    final defaults = await defaultsStore.read(typeId);
    expect(defaults?.visiblePropertyIds, <int>[keepId]);
    expect(defaults?.propertyOrder, <int>[keepId]);
    expect(defaults?.openMode, ObjectOpenMode.fullPage);
    expect(defaults?.bodyTemplate?.blocks.single.text, 'Template notes');
  });

  test('Relation Property deletion stays outside the Lane A boundary', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final deletion = ObjectPropertyDeletionService(
      genericStore: genericStore,
      objectStore: objectStore,
      defaultsStore: defaultsStore,
    );

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Related',
      targetObjectTypeId: targetTypeId,
    );
    await defaultsStore.write(
      objectTypeId: sourceTypeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[relationId],
        propertyOrder: <int>[relationId],
      ),
    );
    final relation = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((candidate) => candidate.id == relationId);

    await expectLater(deletion.deleteProperty(relation), throwsStateError);

    final type = (await objectStore.getObjectType(sourceTypeId))!;
    expect(type.properties.map((property) => property.id), contains(relationId));
    final defaults = await defaultsStore.read(sourceTypeId);
    expect(defaults?.visiblePropertyIds, <int>[relationId]);
    expect(defaults?.propertyOrder, <int>[relationId]);
  });

  test('pre-existing unrelated defaults corruption blocks deletion', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final deletion = ObjectPropertyDeletionService(
      genericStore: genericStore,
      objectStore: objectStore,
      defaultsStore: defaultsStore,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Corrupt defaults',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Delete me',
      type: ObjectPropertyType.text,
    );
    final corruptJson = jsonEncode(
      ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId, 999999],
        propertyOrder: <int>[propertyId, 999999],
      ).toJson(),
    );
    await defaultsStore.ensureSchema();
    await database.customStatement(
      '''INSERT INTO object_type_defaults(object_type_id, defaults_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)''',
      <Object?>[typeId, corruptJson],
    );
    final property = (await objectStore.getObjectType(typeId))!
        .properties
        .singleWhere((candidate) => candidate.id == propertyId);

    await expectLater(
      deletion.deleteProperty(property),
      throwsA(isA<FormatException>()),
    );

    final type = (await objectStore.getObjectType(typeId))!;
    expect(type.properties.map((property) => property.id), contains(propertyId));
    final rows = await database.customSelect(
      'SELECT defaults_json FROM object_type_defaults WHERE object_type_id = $typeId',
    ).get();
    expect(rows, hasLength(1));
    expect(rows.single.read<String>('defaults_json'), corruptJson);
  });
}
