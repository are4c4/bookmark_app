import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Relation creation preserves non-structural metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );

    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Authors',
      targetObjectTypeId: targetTypeId,
      multiple: true,
      metadata: const <String, dynamic>{
        'searchable': false,
        'hidden': true,
      },
    );

    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((candidate) => candidate.id == propertyId);
    expect(property.targetObjectTypeId, targetTypeId);
    expect(property.allowsMultipleRelations, isTrue);
    expect(property.config['searchable'], isFalse);
    expect(property.config['hidden'], isTrue);
  });

  test('canonical Relation creation rejects structural and pair metadata injection',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );

    const reserved = <String, dynamic>{
      'targetObjectTypeId': 999,
      'multiple': false,
      'bidirectional': true,
      'inversePropertyId': 999,
      'pairRole': 'source',
    };
    for (final entry in reserved.entries) {
      await expectLater(
        objectStore.createRelationProperty(
          objectTypeId: sourceTypeId,
          name: 'Injected ${entry.key}',
          targetObjectTypeId: targetTypeId,
          metadata: <String, dynamic>{entry.key: entry.value},
        ),
        throwsArgumentError,
      );
    }

    final sourceType = (await objectStore.getObjectType(sourceTypeId))!;
    expect(
      sourceType.properties.where((property) => property.name.startsWith('Injected ')),
      isEmpty,
    );
  });
}
