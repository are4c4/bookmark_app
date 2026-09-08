import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_editor_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Enter splits a persisted paragraph and focuses the new block',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Keyboard Body',
    );
    final bodyStore = ObjectBodyStore(store);
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'paragraph-1',
            type: 'paragraph',
            text: 'hello world',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectBodyEditorSection(
            store: store,
            objectStore: objectStore,
            objectId: objectId,
            workspaceId: workspaceId,
            showHeading: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final firstEditable = tester.widget<EditableText>(find.byType(EditableText));
    firstEditable.controller.selection =
        const TextSelection.collapsed(offset: 5);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final stored = await bodyStore.read(objectId);
    expect(stored.blocks, hasLength(2));
    expect(stored.blocks[0].text, 'hello');
    expect(stored.blocks[1].text, ' world');
    expect(find.byType(TextField), findsNWidgets(2));

    final secondEditable =
        tester.widget<EditableText>(find.byType(EditableText).at(1));
    expect(secondEditable.focusNode.hasFocus, isTrue);
  });
}
