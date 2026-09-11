import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_merge_state_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_merge_state_planner.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures and conditionally persists exact A-owned merge state', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    await fixture.objectStore.setPropertyValue(
      objectId: fixture.objectId,
      property: fixture.property,
      value: 'old value',
    );
    await fixture.bodyStore.write(
      objectId: fixture.objectId,
      document: _body('old body'),
    );
    await fixture.aliasStore.replaceAliases(
      objectId: fixture.objectId,
      aliases: const <String>['Old Alias'],
    );

    final expected = await fixture.mergeStateStore.capture(
      objectTypeId: fixture.objectTypeId,
      objectId: fixture.objectId,
    );
    expect(expected.title, 'Original');
    expect(expected.propertySnapshots.single.value, 'old value');
    expect(expected.body.toJson(), _body('old body').toJson());
    expect(expected.aliases, const <String>['Old Alias']);

    final next = ObjectMergeStateSnapshot(
      objectId: fixture.objectId,
      objectTypeId: fixture.objectTypeId,
      title: 'Merged title',
      propertySnapshots: <ObjectMergeValuePropertySnapshot>[
        ObjectMergeValuePropertySnapshot.fromDefinition(
          property: fixture.property,
          value: 'merged value',
        ),
      ],
      body: _body('merged body'),
      aliases: const <String>['Merged Alias'],
    );

    expect(
      await fixture.mergeStateStore.writeIfUnchanged(
        expected: expected,
        next: next,
      ),
      isTrue,
    );

    final persisted = await fixture.mergeStateStore.capture(
      objectTypeId: fixture.objectTypeId,
      objectId: fixture.objectId,
    );
    expect(persisted.title, 'Merged title');
    expect(persisted.propertySnapshots.single.value, 'merged value');
    expect(persisted.body.toJson(), _body('merged body').toJson());
    expect(persisted.aliases, const <String>['Merged Alias']);
  });

  test('stale expected state fails before changing any A-owned state', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);

    await fixture.objectStore.setPropertyValue(
      objectId: fixture.objectId,
      property: fixture.property,
      value: 'original value',
    );
    await fixture.bodyStore.write(
      objectId: fixture.objectId,
      document: _body('original body'),
    );
    await fixture.aliasStore.replaceAliases(
      objectId: fixture.objectId,
      aliases: const <String>['Original Alias'],
    );
    final stale = await fixture.mergeStateStore.capture(
      objectTypeId: fixture.objectTypeId,
      objectId: fixture.objectId,
    );

    await fixture.objectStore.renameObject(fixture.objectId, 'Concurrent title');

    final next = ObjectMergeStateSnapshot(
      objectId: fixture.objectId,
      objectTypeId: fixture.objectTypeId,
      title: 'Should not persist',
      propertySnapshots: <ObjectMergeValuePropertySnapshot>[
        ObjectMergeValuePropertySnapshot.fromDefinition(
          property: fixture.property,
          value: 'should not persist',
        ),
      ],
      body: _body('should not persist'),
      aliases: const <String>['Should Not Persist'],
    );

    expect(
      await fixture.mergeStateStore.writeIfUnchanged(
        expected: stale,
        next: next,
      ),
      isFalse,
    );

    final persisted = await fixture.mergeStateStore.capture(
      objectTypeId: fixture.objectTypeId,
      objectId: fixture.objectId,
    );
    expect(persisted.title, 'Concurrent title');
    expect(persisted.propertySnapshots.single.value, 'original value');
    expect(persisted.body.toJson(), _body('original body').toJson());
    expect(persisted.aliases, const <String>['Original Alias']);
  });
}

ObjectBodyDocument _body(String text) => ObjectBodyDocument(
  blocks: <ObjectBodyBlock>[
    ObjectBodyBlock(id: 'p', type: 'paragraph', text: text),
  ],
);

class _Fixture {
  _Fixture({
    required this.database,
    required this.objectStore,
    required this.bodyStore,
    required this.aliasStore,
    required this.mergeStateStore,
    required this.objectTypeId,
    required this.objectId,
    required this.property,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final ObjectBodyStore bodyStore;
  final ObjectAliasStore aliasStore;
  final ObjectMergeStateStore mergeStateStore;
  final int objectTypeId;
  final int objectId;
  final ObjectPropertyDefinition property;

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Merge type',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: 'Value',
      type: ObjectPropertyType.text,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Original',
    );
    final objectType = await objectStore.getObjectType(objectTypeId);
    final property = objectType!.properties.singleWhere(
      (candidate) => candidate.id == propertyId,
    );

    return _Fixture(
      database: database,
      objectStore: objectStore,
      bodyStore: ObjectBodyStore(genericStore),
      aliasStore: ObjectAliasStore(genericStore),
      mergeStateStore: ObjectMergeStateStore(genericStore),
      objectTypeId: objectTypeId,
      objectId: objectId,
      property: property,
    );
  }
}
