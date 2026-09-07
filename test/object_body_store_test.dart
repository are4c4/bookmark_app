import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
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

  test('invalid Body structure fails before replacing persisted content', () async {
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
      title: 'Protected',
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'safe', type: 'paragraph', text: 'keep me'),
        ],
      ),
    );

    await expectLater(
      bodyStore.write(
        objectId: objectId,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(id: 'duplicate', type: 'paragraph'),
            ObjectBodyBlock(id: 'duplicate', type: 'futureWidget'),
          ],
        ),
      ),
      throwsFormatException,
    );

    final restored = await bodyStore.read(objectId);
    expect(restored.blocks, hasLength(1));
    expect(restored.blocks.single.id, 'safe');
    expect(restored.blocks.single.text, 'keep me');
  });

  test('malformed persisted checklist state fails closed without rewriting Body',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Checklist host',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Malformed checklist',
    );
    await bodyStore.ensureSchema();
    const malformedJson =
        '{"version":1,"blocks":[{"id":"check","type":"checklist","attributes":{"checked":"true"}}]}';
    await database.customStatement(
      '''INSERT INTO object_bodies(object_id, document_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)''',
      [objectId, malformedJson],
    );

    await expectLater(bodyStore.read(objectId), throwsFormatException);

    final row = await database.customSelect(
      'SELECT document_json FROM object_bodies WHERE object_id = $objectId',
    ).getSingle();
    expect(row.read<String>('document_json'), malformedJson);

    const valid = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'check',
          type: ObjectBodyBlockType.checklist,
          attributes: <String, dynamic>{ObjectBodyBlockAttribute.checked: false},
        ),
      ],
    );
    await bodyStore.write(objectId: objectId, document: valid);
    expect((await bodyStore.read(objectId)).blocks.single.attributes['checked'], false);
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

  test('clear removes Body, advances Object freshness and keeps Object', () async {
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
    await database.customStatement(
      "UPDATE generic_records SET updated_at = '2000-01-01 00:00:00' WHERE id = ?",
      [objectId],
    );

    await bodyStore.clear(objectId);

    expect((await bodyStore.read(objectId)).isEmpty, isTrue);
    final object = (await objectStore.listObjects(typeId)).single;
    expect(object.id, objectId);
    expect(object.updatedAt.year, isNot(2000));

    await database.customStatement(
      "UPDATE generic_records SET updated_at = '2000-01-01 00:00:00' WHERE id = ?",
      [objectId],
    );
    await bodyStore.clear(objectId);
    expect((await objectStore.listObjects(typeId)).single.updatedAt.year, 2000);
  });

  test('clear rolls Body deletion back when Object freshness update fails', () async {
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
      title: 'Protected body',
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'safe', type: 'paragraph', text: 'keep me'),
        ],
      ),
    );
    await database.customStatement('''
      CREATE TRIGGER fail_object_body_clear_parent_touch
      BEFORE UPDATE OF updated_at ON generic_records
      WHEN OLD.id = $objectId
      BEGIN
        SELECT RAISE(ABORT, 'forced parent freshness failure');
      END
    ''');

    await expectLater(bodyStore.clear(objectId), throwsA(anything));

    final restored = await bodyStore.read(objectId);
    expect(restored.blocks, hasLength(1));
    expect(restored.blocks.single.id, 'safe');
    expect(restored.blocks.single.text, 'keep me');
  });
}
