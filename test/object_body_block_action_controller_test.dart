import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_block_action_controller.dart';
import 'package:bookmark_app/data/object_body_block_edit_service.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_actions.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<({int objectId, ObjectBodyStore store, ObjectBodyBlockActionController controller})> fixture() async {
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
      title: 'Body actions',
    );
    final store = ObjectBodyStore(genericStore);
    final edits = ObjectBodyBlockEditService(bodyStore: store);
    return (
      objectId: objectId,
      store: store,
      controller: ObjectBodyBlockActionController(editService: edits),
    );
  }

  test('insert can create the first block in an empty Body', () async {
    final f = await fixture();

    final next = await f.controller.insert(
      objectId: f.objectId,
      newBlockId: 'first',
      kind: ObjectBodyInsertKind.heading2,
      text: 'Start',
    );

    expect(next.blocks, hasLength(1));
    expect(next.blocks.single.id, 'first');
    expect(next.blocks.single.type, ObjectBodyBlockType.heading);
    expect(next.blocks.single.text, 'Start');
    expect(next.blocks.single.attributes[ObjectBodyBlockAttribute.level], 2);
  });

  test('insertAfter creates selected block immediately after latest anchor', () async {
    final f = await fixture();
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [
        ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph),
        ObjectBodyBlock(id: 'future', type: 'futureBlock', attributes: {'keep': 1}),
      ]),
    );

    final next = await f.controller.insertAfter(
      objectId: f.objectId,
      anchorBlockId: 'a',
      newBlockId: 'check',
      kind: ObjectBodyInsertKind.checklist,
      text: 'Task',
    );

    expect(next.blocks.map((block) => block.id), ['a', 'check', 'future']);
    expect(next.blocks[1].type, ObjectBodyBlockType.checklist);
    expect(next.blocks[1].text, 'Task');
    expect(next.blocks[2].attributes['keep'], 1);
  });

  test('controller delegates relative move and remove operations', () async {
    final f = await fixture();
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [
        ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph),
        ObjectBodyBlock(id: 'b', type: ObjectBodyBlockType.paragraph),
      ]),
    );

    final moved = await f.controller.moveUp(objectId: f.objectId, blockId: 'b');
    expect(moved.blocks.map((block) => block.id), ['b', 'a']);

    final removed = await f.controller.remove(objectId: f.objectId, blockId: 'b');
    expect(removed.blocks.map((block) => block.id), ['a']);
  });

  test('insertAfter fails closed for missing anchor and duplicate new id', () async {
    final f = await fixture();
    const original = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph),
    ]);
    await f.store.write(objectId: f.objectId, document: original);

    await expectLater(
      f.controller.insertAfter(
        objectId: f.objectId,
        anchorBlockId: 'missing',
        newBlockId: 'b',
        kind: ObjectBodyInsertKind.paragraph,
      ),
      throwsStateError,
    );
    await expectLater(
      f.controller.insertAfter(
        objectId: f.objectId,
        anchorBlockId: 'a',
        newBlockId: 'a',
        kind: ObjectBodyInsertKind.paragraph,
      ),
      throwsStateError,
    );
    expect((await f.store.read(f.objectId)).toJson(), original.toJson());
  });
}
