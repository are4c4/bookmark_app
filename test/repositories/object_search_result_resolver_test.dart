import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:bookmark_app/repositories/object_search_result_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves canonical hits in rank order and drops stale mismatches', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final resolver = ObjectSearchResultResolver(objectStore);

    final personType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final bookType = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final ada = await objectStore.createObject(
      objectTypeId: personType,
      title: 'Ada Lovelace',
    );
    final notes = await objectStore.createObject(
      objectTypeId: bookType,
      title: 'Analytical Engine Notes',
    );

    final resolved = await resolver.resolve(<ObjectSearchHit>[
      ObjectSearchHit(
        objectId: notes,
        objectTypeId: bookType,
        workspaceId: workspaceId,
        rank: -4,
        snippet: 'notes',
      ),
      ObjectSearchHit(
        objectId: ada,
        objectTypeId: personType,
        workspaceId: workspaceId,
        rank: -3,
        snippet: 'ada',
      ),
      ObjectSearchHit(
        objectId: 999999,
        objectTypeId: personType,
        workspaceId: workspaceId,
        rank: -2,
        snippet: 'stale object',
      ),
      ObjectSearchHit(
        objectId: ada,
        objectTypeId: bookType,
        workspaceId: workspaceId,
        rank: -1,
        snippet: 'wrong type',
      ),
      ObjectSearchHit(
        objectId: ada,
        objectTypeId: personType,
        workspaceId: workspaceId + 100,
        rank: 0,
        snippet: 'wrong workspace',
      ),
    ]);

    expect(resolved.map((item) => item.object.id), <int>[notes, ada]);
    expect(
      resolved.map((item) => item.object.title),
      <String>['Analytical Engine Notes', 'Ada Lovelace'],
    );
    expect(resolved.map((item) => item.objectType.id), <int>[bookType, personType]);
    expect(resolved.map((item) => item.hit.rank), <double>[-4, -3]);
  });

  test('corrupt ObjectType hit is dropped without losing healthy results', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final resolver = ObjectSearchResultResolver(objectStore);

    final corruptTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Corruptible',
    );
    final corruptPropertyId = await objectStore.createProperty(
      objectTypeId: corruptTypeId,
      name: 'Notes',
      type: ObjectPropertyType.text,
    );
    final healthyTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Healthy',
    );
    final corruptObjectId = await objectStore.createObject(
      objectTypeId: corruptTypeId,
      title: 'Corrupt stale hit',
    );
    final healthyObjectId = await objectStore.createObject(
      objectTypeId: healthyTypeId,
      title: 'Healthy current hit',
    );

    await database.customStatement(
      'UPDATE generic_properties SET type = ? WHERE id = ?',
      ['futureRichText', corruptPropertyId],
    );

    final resolved = await resolver.resolve(<ObjectSearchHit>[
      ObjectSearchHit(
        objectId: corruptObjectId,
        objectTypeId: corruptTypeId,
        workspaceId: workspaceId,
        rank: -2,
        snippet: 'corrupt',
      ),
      ObjectSearchHit(
        objectId: healthyObjectId,
        objectTypeId: healthyTypeId,
        workspaceId: workspaceId,
        rank: -1,
        snippet: 'healthy',
      ),
    ]);

    expect(resolved.map((item) => item.object.id), <int>[healthyObjectId]);
    expect(resolved.single.hit.rank, -1);
  });

  test('empty hit list avoids ObjectStore work and resolves empty', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final resolver = ObjectSearchResultResolver(
      ObjectStore(GenericDatabaseStore(database)),
    );

    expect(
      await resolver.resolve(const <ObjectSearchHit>[]),
      isEmpty,
    );
  });
}
