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
  testWidgets('shared Body editor offers lossless delete Undo', (tester) async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    const initial = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'keep', type: 'paragraph', text: 'Keep'),
        ObjectBodyBlock(
          id: 'delete',
          type: 'paragraph',
          text: 'Restore me',
          attributes: <String, dynamic>{'align': 'center'},
        ),
      ],
    );
    await fixture.bodyStore.write(
      objectId: fixture.objectId,
      document: initial,
    );
    await _pumpEditor(tester, fixture);

    await _deleteBlock(tester, 'delete');

    expect(find.byKey(const ValueKey('body-text-delete')), findsNothing);
    expect(find.text('ブロックを削除しました'), findsOneWidget);
    expect(find.text('元に戻す'), findsOneWidget);
    expect(
      (await fixture.bodyStore.read(fixture.objectId)).blocks
          .map((block) => block.id),
      ['keep'],
    );

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('body-text-delete')), findsOneWidget);
    expect(
      (await fixture.bodyStore.read(fixture.objectId)).toJson(),
      initial.toJson(),
    );
  });

  testWidgets('shared Body editor rejects stale delete Undo', (tester) async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    const initial = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'keep', type: 'paragraph', text: 'Original'),
        ObjectBodyBlock(id: 'delete', type: 'paragraph', text: 'Remove me'),
      ],
    );
    await fixture.bodyStore.write(
      objectId: fixture.objectId,
      document: initial,
    );
    await _pumpEditor(tester, fixture);

    await _deleteBlock(tester, 'delete');
    const newer = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'keep', type: 'paragraph', text: 'Newer edit'),
      ],
    );
    await fixture.bodyStore.write(objectId: fixture.objectId, document: newer);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(find.text('新しい変更があるため元に戻せませんでした。'), findsOneWidget);
    expect(
      (await fixture.bodyStore.read(fixture.objectId)).toJson(),
      newer.toJson(),
    );
  });
}

Future<
  ({
    AppDatabase database,
    GenericDatabaseStore store,
    ObjectStore objectStore,
    ObjectBodyStore bodyStore,
    int workspaceId,
    int objectId,
  })
>
_fixture() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final workspaceId = await WorkspaceStore(database).initialize();
  final store = GenericDatabaseStore(database);
  final objectStore = ObjectStore(store);
  final objectTypeId = await objectStore.createObjectType(
    workspaceId: workspaceId,
    name: 'Note',
  );
  final objectId = await objectStore.createObject(
    objectTypeId: objectTypeId,
    title: 'Undo host',
  );
  return (
    database: database,
    store: store,
    objectStore: objectStore,
    bodyStore: ObjectBodyStore(store),
    workspaceId: workspaceId,
    objectId: objectId,
  );
}

Future<void> _pumpEditor(
  WidgetTester tester,
  ({
    AppDatabase database,
    GenericDatabaseStore store,
    ObjectStore objectStore,
    ObjectBodyStore bodyStore,
    int workspaceId,
    int objectId,
  })
  fixture,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: ObjectBodyEditorSection(
          store: fixture.store,
          objectStore: fixture.objectStore,
          objectId: fixture.objectId,
          workspaceId: fixture.workspaceId,
          showHeading: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _deleteBlock(WidgetTester tester, String blockId) async {
  await tester.tap(find.byKey(ValueKey('body-text-$blockId')));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey('body-block-more-$blockId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('body-block-delete-$blockId')));
  await tester.pumpAndSettle();
}
