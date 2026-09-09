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
  testWidgets(
    'shared Body editor persists reorder without changing block payload',
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
        title: 'Reorder Body',
      );
      final bodyStore = ObjectBodyStore(store);
      await bodyStore.write(
        objectId: objectId,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'a',
              type: 'paragraph',
              text: 'A',
              attributes: <String, dynamic>{'align': 'center'},
            ),
            ObjectBodyBlock(id: 'b', type: 'paragraph', text: 'B'),
            ObjectBodyBlock(id: 'c', type: 'paragraph', text: 'C'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
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

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byKey(const ValueKey('body-block-drag-a')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('body-text-a')));
      await tester.pump();
      expect(find.byKey(const ValueKey('body-block-drag-a')), findsOneWidget);

      final reorderable = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderable.onReorderItem!(0, 2);
      await tester.pumpAndSettle();

      final stored = await bodyStore.read(objectId);
      expect(stored.blocks.map((block) => block.id), <String>['b', 'c', 'a']);
      final moved = stored.blocks.last;
      expect(moved.type, 'paragraph');
      expect(moved.text, 'A');
      expect(moved.attributes, <String, dynamic>{'align': 'center'});
    },
  );
}
