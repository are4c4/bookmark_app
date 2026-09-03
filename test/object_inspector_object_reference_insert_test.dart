import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Object inspector inserts an explicitly selected Object reference only',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final bodyStore = ObjectBodyStore(genericStore);

      final noteTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Note',
        icon: '📝',
      );
      final personTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Person',
        icon: '👤',
      );
      final sourceId = await objectStore.createObject(
        objectTypeId: noteTypeId,
        title: 'メモ',
      );
      final targetId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'Serre',
      );
      await bodyStore.write(
        objectId: sourceId,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'a',
              type: ObjectBodyBlockType.paragraph,
              text: '参照先:',
            ),
          ],
        ),
      );

      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ObjectInspectorPage(
            store: genericStore,
            objectStore: objectStore,
            objectId: sourceId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final referenceAction = find.byKey(
        const ValueKey('body-block-insert-reference-after-a'),
      );
      expect(referenceAction, findsOneWidget);

      await tester.tap(referenceAction);
      await tester.pumpAndSettle();
      expect(find.text('Object を参照'), findsOneWidget);
      expect(find.text('Database / View を埋め込む'), findsNothing);
      expect(find.text('画像を埋め込む'), findsNothing);
      expect(find.text('ファイルを埋め込む'), findsNothing);
      await tester.tap(find.text('Object を参照'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      var document = await bodyStore.read(sourceId);
      expect(document.blocks, hasLength(1));

      await tester.tap(referenceAction);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Object を参照'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('body-object-reference-candidate-$targetId')),
      );
      await tester.pumpAndSettle();

      document = await bodyStore.read(sourceId);
      expect(document.blocks, hasLength(2));
      expect(document.blocks.first.id, 'a');
      final reference = document.blocks.last;
      expect(reference.type, ObjectBodyBlockType.objectReference);
      expect(reference.referencedObjectId, targetId);
      expect(reference.text, 'Serre');
    },
  );
}
