import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known Object Property storage types keep their canonical mapping', () {
    expect(
      ObjectPropertyDefinition.fromStorageType('text'),
      ObjectPropertyType.text,
    );
    expect(
      ObjectPropertyDefinition.fromStorageType('relation'),
      ObjectPropertyType.objectRelation,
    );
    expect(
      ObjectPropertyDefinition.fromStorageType('formula'),
      ObjectPropertyType.formula,
    );
  });

  test('unknown Object Property storage type fails closed', () {
    expect(
      () => ObjectPropertyDefinition.fromStorageType('futureRichText'),
      throwsFormatException,
    );
  });

  test('persisted unknown Property type is not reinterpreted as text', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Corruptible',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: 'Bodyish',
      type: ObjectPropertyType.text,
    );

    await database.customStatement(
      'UPDATE generic_properties SET type = ? WHERE id = ?',
      ['futureRichText', propertyId],
    );

    await expectLater(
      objectStore.getObjectType(objectTypeId),
      throwsFormatException,
    );

    final raw = await database.customSelect(
      'SELECT type FROM generic_properties WHERE id = ?',
      variables: [],
    ).getSingle();
    expect(raw.read<String>('type'), 'futureRichText');
  });
}
