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
  testWidgets('real inspector inserts an explicitly selected Object reference',
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
      title: 'Source note',
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
            id: 'intro',
            type: ObjectBodyBlockType.paragraph,
            text: 'See also',
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
          objectId: sourceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('body-block-insert-reference-after-intro')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Object を参照'), findsOneWidget);
    expect(find.text('画像を埋め込む'), findsNothing);
    await tester.tap(find.text('Object を参照'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('body-object-reference-candidate-$targetId')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('body-object-reference-candidate-$sourceId')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(ValueKey('body-object-reference-candidate-$targetId')),
    );
    await tester.pumpAndSettle();

    final document = await bodyStore.read(sourceId);
    expect(document.blocks, hasLength(2));
    expect(document.blocks.last.type, ObjectBodyBlockType.objectReference);
    expect(document.blocks.last.referencedObjectId, targetId);
    expect(document.blocks.last.text, 'Serre');
    expect(find.text('Serre'), findsOneWidget);

    await tester.tap(find.text('Serre'));
    await tester.pumpAndSettle();
    expect(find.text('Serre'), findsWidgets);
    expect(find.text('Person'), findsOneWidget);
  });

  testWidgets('cancelling Object reference target selection leaves Body unchanged',
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
    final sourceId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Source',
    );
    await objectStore.createObject(objectTypeId: typeId, title: 'Target');

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

    await tester.tap(find.byKey(const ValueKey('body-empty-reference-insert')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Object を参照'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect((await bodyStore.read(sourceId)).blocks, isEmpty);
  });
}
