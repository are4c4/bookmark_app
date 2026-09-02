import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_block_edit_service.dart';
import 'package:bookmark_app/data/object_body_reference_insert_controller.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_reference_insert.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<({
    int objectId,
    ObjectBodyStore store,
    ObjectBodyReferenceInsertController controller,
  })> fixture() async {
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
      title: 'Reference inserts',
    );
    final store = ObjectBodyStore(genericStore);
    final editService = ObjectBodyBlockEditService(bodyStore: store);
    return (
      objectId: objectId,
      store: store,
      controller: ObjectBodyReferenceInsertController(editService: editService),
    );
  }

  test('insert appends a fully selected object reference', () async {
    final f = await fixture();

    await f.controller.insert(
      objectId: f.objectId,
      blockId: 'ref-1',
      request: const ObjectBodyObjectReferenceInsert(objectId: 17),
    );

    final block = (await f.store.read(f.objectId)).blocks.single;
    expect(block.type, ObjectBodyBlockType.objectReference);
    expect(block.referencedObjectId, 17);
  });

  test('insertAfter resolves anchor against latest persisted order', () async {
    final f = await fixture();
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [
        ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph, text: 'A'),
        ObjectBodyBlock(id: 'b', type: ObjectBodyBlockType.paragraph, text: 'B'),
      ]),
    );

    await f.controller.insertAfter(
      objectId: f.objectId,
      anchorBlockId: 'a',
      blockId: 'db-1',
      request: const ObjectBodyDatabaseViewInsert(databaseId: 5, viewId: 6),
    );

    final blocks = (await f.store.read(f.objectId)).blocks;
    expect(blocks.map((block) => block.id).toList(), ['a', 'db-1', 'b']);
    expect(blocks[1].referencedDatabaseId, 5);
    expect(blocks[1].referencedViewId, 6);
  });

  test('invalid request does not mutate persisted Body', () async {
    final f = await fixture();
    const original = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph, text: 'A'),
    ]);
    await f.store.write(objectId: f.objectId, document: original);

    await expectLater(
      f.controller.insert(
        objectId: f.objectId,
        blockId: 'asset',
        request: const ObjectBodyAssetReferenceInsert(
          kind: ObjectBodyAssetReferenceKind.file,
          assetId: 0,
        ),
      ),
      throwsArgumentError,
    );

    expect((await f.store.read(f.objectId)).toJson(), original.toJson());
  });

  test('insertAllocated assigns a semantic collision-free block id', () async {
    final f = await fixture();
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [
        ObjectBodyBlock(
          id: 'object-ref-1',
          type: ObjectBodyBlockType.paragraph,
          text: 'Existing',
        ),
      ]),
    );

    final result = await f.controller.insertAllocated(
      objectId: f.objectId,
      request: const ObjectBodyObjectReferenceInsert(objectId: 22),
    );

    expect(result.blockId, 'object-ref-2');
    expect(result.document.blocks.last.id, 'object-ref-2');
    expect(result.document.blocks.last.referencedObjectId, 22);
  });

  test('insertAfterAllocated returns the generated asset block identity', () async {
    final f = await fixture();
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [
        ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph, text: 'A'),
        ObjectBodyBlock(id: 'file-1', type: ObjectBodyBlockType.paragraph),
      ]),
    );

    final result = await f.controller.insertAfterAllocated(
      objectId: f.objectId,
      anchorBlockId: 'a',
      request: const ObjectBodyAssetReferenceInsert(
        kind: ObjectBodyAssetReferenceKind.file,
        assetId: 7,
      ),
    );

    expect(result.blockId, 'file-2');
    expect(result.document.blocks.map((block) => block.id).toList(), [
      'a',
      'file-2',
      'file-1',
    ]);
    expect(result.document.blocks[1].referencedAssetId, 7);
  });
}
