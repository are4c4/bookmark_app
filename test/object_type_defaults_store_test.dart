import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ObjectType defaults round-trip independently of Database/View state', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[7, 9],
        propertyOrder: <int>[9, 7],
        openMode: ObjectOpenMode.centerPeek,
        bodyTemplate: ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'summary',
              type: 'heading',
              text: 'Summary',
              attributes: <String, dynamic>{'level': 2},
            ),
            ObjectBodyBlock(
              id: 'notes',
              type: 'paragraph',
              text: '',
            ),
          ],
        ),
      ),
    );

    final restored = await defaultsStore.read(typeId);
    expect(restored, isNotNull);
    expect(restored!.visiblePropertyIds, <int>[7, 9]);
    expect(restored.propertyOrder, <int>[9, 7]);
    expect(restored.openMode, ObjectOpenMode.centerPeek);
    expect(restored.bodyTemplate?.blocks, hasLength(2));
    expect(restored.bodyTemplate?.blocks.first.type, 'heading');
    expect(restored.bodyTemplate?.blocks.first.attributes['level'], 2);
    expect(restored.bodyTemplate?.blocks.last.id, 'notes');
  });

  test('new Objects receive current Body template without mutating existing Body',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Paper',
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(
        bodyTemplate: ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'template-notes',
              type: 'paragraph',
              text: 'Initial notes',
            ),
          ],
        ),
      ),
    );

    final firstId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'First paper',
    );
    expect((await bodyStore.read(firstId)).blocks.single.text, 'Initial notes');

    await bodyStore.write(
      objectId: firstId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'template-notes',
            type: 'paragraph',
            text: 'My edited notes',
          ),
        ],
      ),
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(
        bodyTemplate: ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'template-notes',
              type: 'paragraph',
              text: 'Updated template',
            ),
          ],
        ),
      ),
    );

    expect((await bodyStore.read(firstId)).blocks.single.text, 'My edited notes');

    final secondId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Second paper',
    );
    expect((await bodyStore.read(secondId)).blocks.single.text, 'Updated template');
  });

  test('empty defaults clear persisted ObjectType overrides', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.fullPage),
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(),
    );

    expect(await defaultsStore.read(typeId), isNull);
  });

  test('deleting ObjectType cascades persisted defaults', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Temporary',
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.fullPage),
    );

    await objectStore.deleteObjectType(typeId);

    final rows = await database.customSelect(
      'SELECT object_type_id FROM object_type_defaults',
    ).get();
    expect(rows, isEmpty);
  });
}
