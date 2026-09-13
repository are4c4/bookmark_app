import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_block_edit_service.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const editor = ObjectBodyEditor();

  test(
    'pure conversion preserves identity text order and unrelated metadata',
    () {
      const document = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'before', type: 'paragraph', text: 'before'),
          ObjectBodyBlock(
            id: 'target',
            type: 'checklist',
            text: 'convert me',
            attributes: <String, dynamic>{
              ObjectBodyBlockAttribute.checked: true,
              'align': 'center',
              'futureMetadata': 'keep',
            },
          ),
          ObjectBodyBlock(id: 'after', type: 'paragraph', text: 'after'),
        ],
      );

      final converted = editor.convertBlock(
        document: document,
        blockId: 'target',
        targetType: ObjectBodyBlockType.heading,
        headingLevel: 2,
      );

      expect(converted.blocks.map((block) => block.id), [
        'before',
        'target',
        'after',
      ]);
      expect(converted.blocks[1].type, ObjectBodyBlockType.heading);
      expect(converted.blocks[1].text, 'convert me');
      expect(converted.blocks[1].attributes, <String, dynamic>{
        'align': 'center',
        'futureMetadata': 'keep',
        ObjectBodyBlockAttribute.level: 2,
      });
    },
  );

  test('conversion canonicalizes target-specific attributes', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'target',
          type: 'heading',
          text: 'content',
          attributes: <String, dynamic>{
            ObjectBodyBlockAttribute.level: 3,
            ObjectBodyBlockAttribute.checked: true,
            ObjectBodyBlockAttribute.language: 'dart',
            ObjectBodyBlockAttribute.icon: 'old',
            'align': 'center',
          },
        ),
      ],
    );

    final checklist = editor.convertBlock(
      document: document,
      blockId: 'target',
      targetType: ObjectBodyBlockType.checklist,
    );
    expect(checklist.blocks.single.attributes, <String, dynamic>{
      'align': 'center',
      ObjectBodyBlockAttribute.checked: false,
    });

    final code = editor.convertBlock(
      document: checklist,
      blockId: 'target',
      targetType: ObjectBodyBlockType.code,
      codeLanguage: '  dart  ',
    );
    expect(code.blocks.single.attributes, <String, dynamic>{
      'align': 'center',
      ObjectBodyBlockAttribute.language: 'dart',
    });
  });

  test('same-kind conversion is an identity no-op', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'heading',
          type: 'heading',
          text: 'unchanged',
          attributes: <String, dynamic>{ObjectBodyBlockAttribute.level: 3},
        ),
      ],
    );

    final result = editor.convertBlock(
      document: document,
      blockId: 'heading',
      targetType: ObjectBodyBlockType.heading,
      headingLevel: 1,
    );

    expect(identical(result, document), isTrue);
    expect(result.blocks.single.attributes, <String, dynamic>{
      ObjectBodyBlockAttribute.level: 3,
    });
  });

  test('reference divider and unknown blocks fail closed', () {
    const reference = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'reference',
          type: ObjectBodyBlockType.objectReference,
          attributes: <String, dynamic>{ObjectBodyBlockAttribute.objectId: 42},
        ),
      ],
    );
    const divider = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'divider', type: ObjectBodyBlockType.divider),
      ],
    );
    const future = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'future',
          type: 'future-rich-block',
          text: 'opaque',
        ),
      ],
    );

    expect(
      () => editor.convertBlock(
        document: reference,
        blockId: 'reference',
        targetType: ObjectBodyBlockType.paragraph,
      ),
      throwsStateError,
    );
    expect(
      () => editor.convertBlock(
        document: divider,
        blockId: 'divider',
        targetType: ObjectBodyBlockType.paragraph,
      ),
      throwsStateError,
    );
    expect(
      () => editor.convertBlock(
        document: future,
        blockId: 'future',
        targetType: ObjectBodyBlockType.paragraph,
      ),
      throwsStateError,
    );
    expect(
      () => editor.convertBlock(
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(id: 'p', type: 'paragraph', text: 'safe'),
          ],
        ),
        blockId: 'p',
        targetType: ObjectBodyBlockType.objectReference,
      ),
      throwsArgumentError,
    );
  });

  test('persisted conversion uses the existing Body CAS path', () async {
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
      title: 'Conversion',
    );
    final bodyStore = ObjectBodyStore(genericStore);
    final service = ObjectBodyBlockEditService(bodyStore: bodyStore);
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'a', type: 'paragraph', text: 'before'),
          ObjectBodyBlock(
            id: 'b',
            type: 'paragraph',
            text: 'target',
            attributes: <String, dynamic>{'align': 'center'},
          ),
        ],
      ),
    );

    final result = await service.convertBlock(
      objectId: objectId,
      blockId: 'b',
      targetType: ObjectBodyBlockType.checklist,
      checklistChecked: true,
    );

    expect(result.blocks.map((block) => block.id), ['a', 'b']);
    expect(result.blocks.last.type, ObjectBodyBlockType.checklist);
    expect(result.blocks.last.text, 'target');
    expect(result.blocks.last.attributes, <String, dynamic>{
      'align': 'center',
      ObjectBodyBlockAttribute.checked: true,
    });
    expect((await bodyStore.read(objectId)).toJson(), result.toJson());
  });

  test(
    'conversion reports a concurrent CAS rejection without committing',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final genericStore = GenericDatabaseStore(database);
      const current = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p', type: 'paragraph', text: 'current'),
        ],
      );
      final bodyStore = _RejectingBodyStore(genericStore, current);
      final service = ObjectBodyBlockEditService(bodyStore: bodyStore);

      await expectLater(
        service.convertBlock(
          objectId: 1,
          blockId: 'p',
          targetType: ObjectBodyBlockType.heading,
        ),
        throwsStateError,
      );

      expect(bodyStore.writeAttempts, 1);
      expect(
        bodyStore.lastProposed?.blocks.single.type,
        ObjectBodyBlockType.heading,
      );
      expect((await bodyStore.read(1)).toJson(), current.toJson());
    },
  );
}

class _RejectingBodyStore extends ObjectBodyStore {
  _RejectingBodyStore(GenericDatabaseStore store, this.current) : super(store);

  final ObjectBodyDocument current;
  int writeAttempts = 0;
  ObjectBodyDocument? lastProposed;

  @override
  Future<ObjectBodyDocument> read(int objectId) async => current;

  @override
  Future<bool> writeIfUnchanged({
    required int objectId,
    required ObjectBodyDocument expected,
    required ObjectBodyDocument document,
  }) async {
    writeAttempts += 1;
    lastProposed = document;
    return false;
  }
}
