import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_block_edit_service.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<({int objectId, ObjectBodyStore store, ObjectBodyBlockEditService service})>
      fixture() async {
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
      title: 'Body interactions',
    );
    final store = ObjectBodyStore(genericStore);
    return (
      objectId: objectId,
      store: store,
      service: ObjectBodyBlockEditService(bodyStore: store),
    );
  }

  test('text edit preserves rich attributes from latest persisted block', () async {
    final f = await fixture();
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [
        ObjectBodyBlock(
          id: 'code-1',
          type: ObjectBodyBlockType.code,
          text: 'old',
          attributes: {'language': 'dart', 'future': 'keep'},
        ),
      ]),
    );

    await f.service.updateText(
      objectId: f.objectId,
      blockId: 'code-1',
      text: 'new',
    );

    final block = (await f.store.read(f.objectId)).blocks.single;
    expect(block.text, 'new');
    expect(block.attributes, {'language': 'dart', 'future': 'keep'});
  });

  test('checklist toggle preserves text and unrelated attributes', () async {
    final f = await fixture();
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [
        ObjectBodyBlock(
          id: 'check-1',
          type: ObjectBodyBlockType.checklist,
          text: 'Task',
          attributes: {'checked': false, 'future': 7},
        ),
      ]),
    );

    await f.service.setChecklistChecked(
      objectId: f.objectId,
      blockId: 'check-1',
      checked: true,
    );

    final block = (await f.store.read(f.objectId)).blocks.single;
    expect(block.text, 'Task');
    expect(block.attributes['checked'], isTrue);
    expect(block.attributes['future'], 7);
  });

  test('interaction mutations fail closed for incompatible blocks', () async {
    final f = await fixture();
    const original = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'divider', type: ObjectBodyBlockType.divider),
    ]);
    await f.store.write(objectId: f.objectId, document: original);

    await expectLater(
      f.service.updateText(
        objectId: f.objectId,
        blockId: 'divider',
        text: 'no',
      ),
      throwsStateError,
    );
    await expectLater(
      f.service.setChecklistChecked(
        objectId: f.objectId,
        blockId: 'divider',
        checked: true,
      ),
      throwsStateError,
    );
    expect((await f.store.read(f.objectId)).toJson(), original.toJson());
  });
}
