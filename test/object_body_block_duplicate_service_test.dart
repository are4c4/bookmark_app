import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_block_duplicate_service.dart';
import 'package:bookmark_app/data/object_body_block_edit_service.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<({
    int objectId,
    ObjectBodyStore store,
    ObjectBodyBlockDuplicateService service,
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
      title: 'Duplicate blocks',
    );
    final store = ObjectBodyStore(genericStore);
    final editService = ObjectBodyBlockEditService(bodyStore: store);
    return (
      objectId: objectId,
      store: store,
      service: ObjectBodyBlockDuplicateService(editService: editService),
    );
  }

  test('duplicates after source with a new stable identity', () async {
    final f = await fixture();
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [
        ObjectBodyBlock(id: 'p', type: ObjectBodyBlockType.paragraph, text: 'A'),
        ObjectBodyBlock(
          id: 'paragraph-copy-1',
          type: ObjectBodyBlockType.paragraph,
          text: 'Existing copy',
        ),
        ObjectBodyBlock(id: 'tail', type: ObjectBodyBlockType.paragraph, text: 'B'),
      ]),
    );

    final result = await f.service.duplicateAfter(
      objectId: f.objectId,
      sourceBlockId: 'p',
    );

    expect(result.blockId, 'paragraph-copy-2');
    expect(result.document.blocks.map((block) => block.id).toList(), [
      'p',
      'paragraph-copy-2',
      'paragraph-copy-1',
      'tail',
    ]);
    expect(result.document.blocks[1].text, 'A');
  });

  test('preserves unknown future payload when duplicating', () async {
    final f = await fixture();
    const source = ObjectBodyBlock(
      id: 'future',
      type: 'future-widget',
      text: 'opaque',
      attributes: <String, dynamic>{
        'nested': <String, dynamic>{'value': 3},
        'flag': true,
      },
    );
    await f.store.write(
      objectId: f.objectId,
      document: const ObjectBodyDocument(blocks: [source]),
    );

    final result = await f.service.duplicateAfter(
      objectId: f.objectId,
      sourceBlockId: 'future',
    );

    final duplicate = result.document.blocks[1];
    expect(duplicate.id, 'future-widget-copy-1');
    expect(duplicate.type, source.type);
    expect(duplicate.text, source.text);
    expect(duplicate.attributes, source.attributes);
  });

  test('missing or blank source fails without rewriting Body', () async {
    final f = await fixture();
    const original = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph, text: 'A'),
    ]);
    await f.store.write(objectId: f.objectId, document: original);

    await expectLater(
      f.service.duplicateAfter(objectId: f.objectId, sourceBlockId: 'missing'),
      throwsStateError,
    );
    await expectLater(
      f.service.duplicateAfter(objectId: f.objectId, sourceBlockId: '   '),
      throwsArgumentError,
    );

    expect((await f.store.read(f.objectId)).toJson(), original.toJson());
  });
}
