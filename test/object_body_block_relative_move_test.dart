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
  Future<({int objectId, ObjectBodyStore store, ObjectBodyBlockEditService service})> fixture() async {
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
      title: 'Body move',
    );
    final store = ObjectBodyStore(genericStore);
    return (
      objectId: objectId,
      store: store,
      service: ObjectBodyBlockEditService(bodyStore: store),
    );
  }

  const document = ObjectBodyDocument(blocks: [
    ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph, text: 'A'),
    ObjectBodyBlock(id: 'b', type: ObjectBodyBlockType.paragraph, text: 'B'),
    ObjectBodyBlock(id: 'c', type: 'futureBlock', attributes: {'keep': true}),
  ]);

  test('moveUp and moveDown use latest persisted ordering', () async {
    final f = await fixture();
    await f.store.write(objectId: f.objectId, document: document);

    final afterUp = await f.service.moveUp(objectId: f.objectId, blockId: 'b');
    expect(afterUp.blocks.map((block) => block.id), ['b', 'a', 'c']);

    final afterDown = await f.service.moveDown(objectId: f.objectId, blockId: 'a');
    expect(afterDown.blocks.map((block) => block.id), ['b', 'c', 'a']);
    expect(afterDown.blocks[1].attributes['keep'], isTrue);
  });

  test('relative moves are no-op at boundaries', () async {
    final f = await fixture();
    await f.store.write(objectId: f.objectId, document: document);

    final first = await f.service.moveUp(objectId: f.objectId, blockId: 'a');
    final last = await f.service.moveDown(objectId: f.objectId, blockId: 'c');

    expect(first.toJson(), document.toJson());
    expect(last.toJson(), document.toJson());
  });

  test('relative move rejects missing or empty block ids without rewriting Body', () async {
    final f = await fixture();
    await f.store.write(objectId: f.objectId, document: document);

    await expectLater(
      f.service.moveUp(objectId: f.objectId, blockId: ''),
      throwsArgumentError,
    );
    await expectLater(
      f.service.moveDown(objectId: f.objectId, blockId: 'missing'),
      throwsStateError,
    );
    expect((await f.store.read(f.objectId)).toJson(), document.toJson());
  });
}
