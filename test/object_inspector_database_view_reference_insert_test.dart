import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Object inspector inserts an explicitly selected Database View after an anchor',
    (tester) async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      await fixture.bodyStore.write(
        objectId: fixture.sourceId,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'a',
              type: ObjectBodyBlockType.paragraph,
              text: '埋め込み:',
            ),
          ],
        ),
      );
      await _pumpInspector(tester, fixture);

      final referenceAction = find.byKey(
        const ValueKey('body-block-insert-reference-after-a'),
      );
      await tester.tap(referenceAction);
      await tester.pumpAndSettle();
      expect(find.text('Object を参照'), findsOneWidget);
      expect(find.text('Database / View を埋め込む'), findsOneWidget);
      expect(find.text('画像を埋め込む'), findsNothing);
      expect(find.text('ファイルを埋め込む'), findsNothing);

      await tester.tap(find.text('Database / View を埋め込む'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect((await fixture.bodyStore.read(fixture.sourceId)).blocks, hasLength(1));

      await tester.tap(referenceAction);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Database / View を埋め込む'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey(
            'body-database-view-reference-${fixture.targetDatabaseId}-view-${fixture.targetViewId}',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = await fixture.bodyStore.read(fixture.sourceId);
      expect(document.blocks, hasLength(2));
      expect(document.blocks.first.id, 'a');
      final reference = document.blocks.last;
      expect(reference.type, ObjectBodyBlockType.databaseView);
      expect(reference.referencedDatabaseId, fixture.targetDatabaseId);
      expect(reference.referencedViewId, fixture.targetViewId);
    },
  );

  testWidgets(
    'Object inspector inserts a Database as the first Body reference block',
    (tester) async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      await _pumpInspector(tester, fixture);

      await tester.tap(
        find.byKey(const ValueKey('body-empty-reference-insert')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Object を参照'), findsOneWidget);
      expect(find.text('Database / View を埋め込む'), findsOneWidget);
      expect(find.text('画像を埋め込む'), findsNothing);
      expect(find.text('ファイルを埋め込む'), findsNothing);
      await tester.tap(find.text('Database / View を埋め込む'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey(
            'body-database-view-reference-${fixture.targetDatabaseId}-database',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = await fixture.bodyStore.read(fixture.sourceId);
      expect(document.blocks, hasLength(1));
      final reference = document.blocks.single;
      expect(reference.type, ObjectBodyBlockType.databaseView);
      expect(reference.referencedDatabaseId, fixture.targetDatabaseId);
      expect(reference.referencedViewId, isNull);
    },
  );
}

Future<void> _pumpInspector(WidgetTester tester, _Fixture fixture) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ObjectInspectorPage(
        store: fixture.genericStore,
        objectStore: fixture.objectStore,
        objectId: fixture.sourceId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.genericStore,
    required this.objectStore,
    required this.bodyStore,
    required this.sourceId,
    required this.targetDatabaseId,
    required this.targetViewId,
  });

  final AppDatabase database;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final ObjectBodyStore bodyStore;
  final int sourceId;
  final int targetDatabaseId;
  final int targetViewId;

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final noteTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
      icon: '📝',
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: noteTypeId,
      title: 'メモ',
    );
    final targetDatabaseId = await genericStore.createDatabase(
      workspaceId: workspaceId,
      name: '読書管理',
      icon: '📚',
    );
    final definition = DatabaseDefinition(
      key: 'custom:$targetDatabaseId',
      label: '読書管理',
      icon: Icons.book_outlined,
      properties: const [],
    );
    final targetViewId = await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: definition,
      name: '読書中',
    );

    return _Fixture(
      database: database,
      genericStore: genericStore,
      objectStore: objectStore,
      bodyStore: bodyStore,
      sourceId: sourceId,
      targetDatabaseId: targetDatabaseId,
      targetViewId: targetViewId,
    );
  }
}
