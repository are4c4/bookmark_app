import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_editor_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('slash conversion restores caret to the removed command start', (
    tester,
  ) async {
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
      title: 'Slash caret',
    );
    final bodyStore = ObjectBodyStore(store);
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p', type: 'paragraph', text: ''),
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

    await tester.enterText(find.byType(TextField), 'hello /h2');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('body-slash-command-heading-2')),
    );
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(
      editable.controller.selection,
      const TextSelection.collapsed(offset: 6),
    );
  });
}
