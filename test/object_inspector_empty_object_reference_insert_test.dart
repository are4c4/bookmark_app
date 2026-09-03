import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty Object Body can start with an explicit Object reference',
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
      title: '空のメモ',
    );
    final targetId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
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

    await tester.tap(find.byKey(const ValueKey('body-empty-reference-insert')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Object を参照'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('body-object-reference-candidate-$targetId')),
    );
    await tester.pumpAndSettle();

    final document = await bodyStore.read(sourceId);
    expect(document.blocks, hasLength(1));
    expect(document.blocks.single.type, ObjectBodyBlockType.objectReference);
    expect(document.blocks.single.referencedObjectId, targetId);
    expect(document.blocks.single.text, 'Serre');
  });
}
