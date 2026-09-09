import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_block_edit_service.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('block edits persist without flattening unknown rich blocks', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Body test',
    );
    final bodyStore = ObjectBodyStore(genericStore);
    final service = ObjectBodyBlockEditService(bodyStore: bodyStore);

    const futureBlock = ObjectBodyBlock(
      id: 'embed-1',
      type: 'embeddedObject',
      attributes: <String, dynamic>{'objectId': 999, 'display': 'card'},
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'first'),
          futureBlock,
        ],
      ),
    );

    await service.insert(
      objectId: objectId,
      block: const ObjectBodyBlock(id: 'p2', type: 'paragraph', text: 'second'),
      index: 1,
    );
    await service.update(
      objectId: objectId,
      block: const ObjectBodyBlock(
        id: 'p2',
        type: 'paragraph',
        text: 'changed',
      ),
    );
    await service.move(objectId: objectId, blockId: 'embed-1', toIndex: 0);
    await service.remove(objectId: objectId, blockId: 'p1');

    final stored = await bodyStore.read(objectId);
    expect(stored.blocks.map((block) => block.id), ['embed-1', 'p2']);
    expect(stored.blocks.first.toJson(), futureBlock.toJson());
    expect(stored.blocks.last.text, 'changed');
  });

  test('paragraph split persists both halves in one document update', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Split test',
    );
    final bodyStore = ObjectBodyStore(genericStore);
    final service = ObjectBodyBlockEditService(bodyStore: bodyStore);
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'p1',
            type: 'paragraph',
            text: 'hello brave world',
            attributes: <String, dynamic>{'align': 'center'},
          ),
          ObjectBodyBlock(id: 'p3', type: 'paragraph', text: 'after'),
        ],
      ),
    );

    final result = await service.splitParagraph(
      objectId: objectId,
      blockId: 'p1',
      newBlockId: 'p2',
      selectionStart: 5,
      selectionEnd: 11,
    );

    expect(result.blocks.map((block) => block.id), ['p1', 'p2', 'p3']);
    expect(result.blocks[0].text, 'hello');
    expect(result.blocks[0].attributes, {'align': 'center'});
    expect(result.blocks[1].text, ' world');
    expect(result.blocks[2].text, 'after');
    expect((await bodyStore.read(objectId)).toJson(), result.toJson());
  });

  test(
    'safe paragraph merge persists once and preserves later blocks',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final objectTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Note',
      );
      final objectId = await objectStore.createObject(
        objectTypeId: objectTypeId,
        title: 'Merge test',
      );
      final bodyStore = ObjectBodyStore(genericStore);
      final service = ObjectBodyBlockEditService(bodyStore: bodyStore);
      await bodyStore.write(
        objectId: objectId,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'hello '),
            ObjectBodyBlock(id: 'p2', type: 'paragraph', text: 'world'),
            ObjectBodyBlock(id: 'p3', type: 'paragraph', text: 'after'),
          ],
        ),
      );

      final result = await service.mergeParagraphIntoPrevious(
        objectId: objectId,
        blockId: 'p2',
      );

      expect(result.blocks.map((block) => block.id), ['p1', 'p3']);
      expect(result.blocks.first.text, 'hello world');
      expect(result.blocks.last.text, 'after');
      expect((await bodyStore.read(objectId)).toJson(), result.toJson());
    },
  );

  test('failed block edit leaves persisted Body unchanged', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Body test',
    );
    final bodyStore = ObjectBodyStore(genericStore);
    final service = ObjectBodyBlockEditService(bodyStore: bodyStore);
    const initial = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'safe'),
      ],
    );
    await bodyStore.write(objectId: objectId, document: initial);

    await expectLater(
      service.remove(objectId: objectId, blockId: 'missing'),
      throwsStateError,
    );

    expect((await bodyStore.read(objectId)).toJson(), initial.toJson());
  });
}
