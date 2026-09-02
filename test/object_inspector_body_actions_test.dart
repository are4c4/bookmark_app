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
  testWidgets('Object inspector persists shared Body block actions',
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
      title: 'Body actions',
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'a',
            type: ObjectBodyBlockType.paragraph,
            text: 'A',
          ),
          ObjectBodyBlock(
            id: 'b',
            type: ObjectBodyBlockType.paragraph,
            text: 'B',
          ),
        ],
      ),
    );

    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    expect(find.byKey(const ValueKey('body-block-move-down-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('body-block-duplicate-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('body-block-delete-a')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('body-block-move-down-a')));
    await tester.pumpAndSettle();
    var document = await bodyStore.read(objectId);
    expect(document.blocks.map((block) => block.id).toList(), <String>['b', 'a']);

    await tester.tap(find.byKey(const ValueKey('body-block-duplicate-a')));
    await tester.pumpAndSettle();
    document = await bodyStore.read(objectId);
    expect(document.blocks.map((block) => block.id).toList(),
        <String>['b', 'a', 'paragraph-copy-1']);
    expect(document.blocks.last.text, 'A');

    await tester.tap(find.byKey(const ValueKey('body-block-insert-after-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('見出し 1').last);
    await tester.pumpAndSettle();
    document = await bodyStore.read(objectId);
    final aIndex = document.blocks.indexWhere((block) => block.id == 'a');
    expect(document.blocks[aIndex + 1].type, ObjectBodyBlockType.heading);
    expect(document.blocks[aIndex + 1].attributes['level'], 1);

    await tester.tap(find.byKey(const ValueKey('body-block-delete-a')));
    await tester.pumpAndSettle();
    document = await bodyStore.read(objectId);
    expect(document.blocks.any((block) => block.id == 'a'), isFalse);
  });

  testWidgets('empty Object Body can create its first block', (tester) async {
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
      title: 'Empty Body',
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

    await tester.tap(find.byKey(const ValueKey('body-empty-insert')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('テキスト').last);
    await tester.pumpAndSettle();

    final document = await bodyStore.read(objectId);
    expect(document.blocks, hasLength(1));
    expect(document.blocks.single.type, ObjectBodyBlockType.paragraph);
  });
}
