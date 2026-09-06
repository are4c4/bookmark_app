import 'package:bookmark_app/data/app_database.dart';
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
  testWidgets('system Weblink and Image Objects expose the shared Body editor',
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
    final weblinkId = await objectStore.createObject(
      objectTypeId: weblinkType.id,
      title: 'Example Weblink',
    );
    final imageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Example Image',
    );

    Future<void> openInspector(int objectId) async {
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
    }

    Future<void> createAndEditBody(int objectId, String text) async {
      expect(find.byKey(const ValueKey('body-empty-insert')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('body-empty-insert')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('テキスト').last);
      await tester.pumpAndSettle();

      var body = await bodyStore.read(objectId);
      expect(body.blocks, hasLength(1));
      expect(body.blocks.single.type, ObjectBodyBlockType.paragraph);

      await tester.enterText(
        find.byKey(ValueKey('body-text-${body.blocks.single.id}')),
        text,
      );
      await tester.pumpAndSettle();
      body = await bodyStore.read(objectId);
      expect(body.blocks.single.text, text);
    }

    await openInspector(weblinkId);
    await createAndEditBody(weblinkId, 'Weblink notes');

    await openInspector(imageId);
    await createAndEditBody(imageId, 'Image notes');
  });
}
