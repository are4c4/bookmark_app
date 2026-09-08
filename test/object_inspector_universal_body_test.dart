import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('system, custom, and Daily Note Objects share the Body editor',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final weblinkType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    final imageType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final dailyNoteType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: DailyNoteService.systemKey,
      name: 'Daily Note',
      icon: '📅',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
      icon: '👤',
    );

    final weblinkId = await objectStore.createObject(
      objectTypeId: weblinkType.id,
      title: 'Example Weblink',
    );
    final imageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Example Image',
    );
    final dailyNoteId = await objectStore.createObject(
      objectTypeId: dailyNoteType.id,
      title: '2026-09-07',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Ada Lovelace',
    );

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> openInspector(int objectId, int revision) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ObjectInspectorPage(
            key: ValueKey('inspector-$objectId-$revision'),
            store: genericStore,
            objectStore: objectStore,
            objectId: objectId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Objectが見つかりません'), findsNothing);
    }

    Future<void> revealInInspector(Finder target) async {
      for (
        var attempt = 0;
        attempt < 8 && target.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await tester.pump();
      }
    }

    Future<void> verifyEditableBody(int objectId, String text) async {
      await openInspector(objectId, 0);
      expect(find.byKey(const ValueKey('body-empty-insert')), findsOneWidget);

      await bodyStore.write(
        objectId: objectId,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'body',
              type: ObjectBodyBlockType.paragraph,
              text: 'Initial',
            ),
          ],
        ),
      );
      await openInspector(objectId, 1);

      final textField = find.byKey(const ValueKey('body-text-body'));
      await revealInInspector(textField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, text);
      await tester.pumpAndSettle();

      final body = await bodyStore.read(objectId);
      expect(body.blocks.single.text, text);
    }

    await verifyEditableBody(weblinkId, 'Weblink notes');
    await verifyEditableBody(imageId, 'Image notes');
    await verifyEditableBody(personId, 'Person notes');
    await verifyEditableBody(dailyNoteId, 'Daily notes');
  });
}
