import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_block_edit_service.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_body_structural_undo_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<
    ({
      int objectId,
      ObjectBodyStore bodyStore,
      ObjectBodyStructuralUndoService undoService,
    })
  >
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
      title: 'Undo Body',
    );
    final bodyStore = ObjectBodyStore(genericStore);
    return (
      objectId: objectId,
      bodyStore: bodyStore,
      undoService: ObjectBodyStructuralUndoService(bodyStore: bodyStore),
    );
  }

  test(
    'delete undo restores exact block payload and original position',
    () async {
      final setup = await fixture();
      const deleted = ObjectBodyBlock(
        id: 'reference',
        type: ObjectBodyBlockType.objectReference,
        text: 'Linked object',
        attributes: <String, dynamic>{ObjectBodyBlockAttribute.objectId: 42},
      );
      const initial = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'before', type: 'paragraph', text: 'Before'),
          deleted,
          ObjectBodyBlock(id: 'after', type: 'paragraph', text: 'After'),
        ],
      );
      await setup.bodyStore.write(objectId: setup.objectId, document: initial);

      final deletion = await setup.undoService.deleteWithUndo(
        objectId: setup.objectId,
        blockId: deleted.id,
      );

      expect(deletion.document.blocks.map((block) => block.id), [
        'before',
        'after',
      ]);
      expect(deletion.undoToken.deletedIndex, 1);
      expect(deletion.undoToken.deletedBlock.toJson(), deleted.toJson());

      final restored = await setup.undoService.undoDelete(deletion.undoToken);

      expect(restored.toJson(), initial.toJson());
      expect(
        (await setup.bodyStore.read(setup.objectId)).toJson(),
        initial.toJson(),
      );
    },
  );

  test(
    'stale delete undo fails closed and preserves newer Body edits',
    () async {
      final setup = await fixture();
      const initial = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'keep', type: 'paragraph', text: 'Original'),
          ObjectBodyBlock(id: 'delete', type: 'paragraph', text: 'Remove me'),
        ],
      );
      await setup.bodyStore.write(objectId: setup.objectId, document: initial);
      final deletion = await setup.undoService.deleteWithUndo(
        objectId: setup.objectId,
        blockId: 'delete',
      );

      final edits = ObjectBodyBlockEditService(bodyStore: setup.bodyStore);
      await edits.updateText(
        objectId: setup.objectId,
        blockId: 'keep',
        text: 'Newer edit',
      );

      await expectLater(
        setup.undoService.undoDelete(deletion.undoToken),
        throwsA(isA<ObjectBodyUndoConflict>()),
      );

      final stored = await setup.bodyStore.read(setup.objectId);
      expect(stored.blocks.map((block) => block.id), ['keep']);
      expect(stored.blocks.single.text, 'Newer edit');
    },
  );

  test('an undo token cannot be applied twice', () async {
    final setup = await fixture();
    const initial = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'only', type: 'paragraph', text: 'Exact'),
      ],
    );
    await setup.bodyStore.write(objectId: setup.objectId, document: initial);
    final deletion = await setup.undoService.deleteWithUndo(
      objectId: setup.objectId,
      blockId: 'only',
    );

    await setup.undoService.undoDelete(deletion.undoToken);
    await expectLater(
      setup.undoService.undoDelete(deletion.undoToken),
      throwsA(isA<ObjectBodyUndoConflict>()),
    );

    expect(
      (await setup.bodyStore.read(setup.objectId)).toJson(),
      initial.toJson(),
    );
  });
}
