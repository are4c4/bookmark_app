import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Object Body defaults empty and round-trips blocks', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Sample',
    );

    expect((await bodyStore.read(objectId)).isEmpty, isTrue);

    final document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock.paragraph(id: 'p1', text: 'hello'),
        const ObjectBodyBlock(
          id: 'future-1',
          type: 'futureWidget',
          attributes: <String, dynamic>{'answer': 42},
        ),
      ],
    );
    await bodyStore.write(objectId: objectId, document: document);

    final restored = await bodyStore.read(objectId);
    expect(restored.version, ObjectBodyDocument.currentVersion);
    expect(restored.blocks.length, 2);
    expect(restored.blocks.first.text, 'hello');
    expect(restored.blocks.last.type, 'futureWidget');
    expect(restored.blocks.last.attributes['answer'], 42);
  });

  test('deleting an Object cascades its Body row', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Temporary',
    );
    await bodyStore.write(
      objectId: objectId,
      document: ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock.paragraph(id: 'p1', text: 'delete me'),
        ],
      ),
    );

    await objectStore.deleteObject(objectId);

    final rows = await database.customSelect(
      'SELECT object_id FROM object_bodies',
    ).get();
    expect(rows, isEmpty);
  });

  test('clear removes Body without deleting the Object', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Keep object',
    );
    await bodyStore.write(
      objectId: objectId,
      document: ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock.paragraph(id: 'p1', text: 'body'),
        ],
      ),
    );

    await bodyStore.clear(objectId);

    expect((await bodyStore.read(objectId)).isEmpty, isTrue);
    expect((await objectStore.listObjects(typeId)).single.id, objectId);
  });
}
