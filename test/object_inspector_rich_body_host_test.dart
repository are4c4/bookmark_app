import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_document_view.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Object inspector edits rich Body blocks without flattening unknown payloads',
      (tester) async {
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
      title: 'Rich body',
    );
    const unknown = ObjectBodyBlock(
      id: 'future-1',
      type: 'futureWidget',
      text: 'preserve me',
      attributes: <String, dynamic>{
        'futureFlag': true,
        'nested': <String, dynamic>{'version': 7},
      },
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'paragraph-1',
            type: ObjectBodyBlockType.paragraph,
            text: 'before',
          ),
          ObjectBodyBlock(
            id: 'checklist-1',
            type: ObjectBodyBlockType.checklist,
            text: 'task',
            attributes: <String, dynamic>{
              ObjectBodyBlockAttribute.checked: false,
              'keep': 'metadata',
            },
          ),
          unknown,
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ObjectBodyDocumentView), findsOneWidget);
    expect(find.text('Unsupported block: futureWidget'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('body-text-paragraph-1')),
      'after',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final stored = await bodyStore.read(objectId);
    final paragraph = stored.blocks.singleWhere(
      (block) => block.id == 'paragraph-1',
    );
    final checklist = stored.blocks.singleWhere(
      (block) => block.id == 'checklist-1',
    );
    final preserved = stored.blocks.singleWhere(
      (block) => block.id == 'future-1',
    );

    expect(paragraph.text, 'after');
    expect(checklist.attributes[ObjectBodyBlockAttribute.checked], isTrue);
    expect(checklist.attributes['keep'], 'metadata');
    expect(preserved.toJson(), unknown.toJson());
  });
}
