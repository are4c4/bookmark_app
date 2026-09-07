import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/views/object_global_search_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'nested Daily Note Body edit from Search refreshes new and stale tokens',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final bodyStore = ObjectBodyStore(store);
    final dailyNotes = DailyNoteService(
      genericStore: store,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(store),
    );

    final noteA = await dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 3),
    );
    final noteB = await dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 4),
    );
    await bodyStore.write(
      objectId: noteA.id,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'search-root-body',
            type: 'paragraph',
            text: 'RootVisitToken',
          ),
        ],
      ),
    );
    await bodyStore.write(
      objectId: noteB.id,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'nested-daily-note-body',
            type: 'paragraph',
            text: 'StaleNestedToken',
          ),
        ],
      ),
    );

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectGlobalSearchPage(
          store: store,
          workspaceId: workspaceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'rootvisittoken');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    final rootResult = find.byKey(
      ValueKey('object-global-search-result-${noteA.id}'),
    );
    expect(rootResult, findsOneWidget);
    await tester.tap(rootResult);
    await tester.pumpAndSettle();

    expect(find.byType(ObjectInspectorPage), findsOneWidget);
    expect(find.text('2026-09-03'), findsWidgets);

    await tester.tap(find.byTooltip('次の日'));
    await tester.pumpAndSettle();

    expect(find.byType(ObjectInspectorPage), findsOneWidget);
    expect(find.text('2026-09-04'), findsWidgets);

    final nestedBody = find.byKey(
      const ValueKey('body-text-nested-daily-note-body'),
    );
    expect(nestedBody, findsOneWidget);
    await tester.enterText(nestedBody, 'FreshNestedToken');
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('2026-09-03'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ObjectGlobalSearchPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'freshnestedtoken');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-global-search-result-${noteB.id}')),
      findsOneWidget,
      reason:
          'returning from Search detail must refresh the nested Daily Note FTS row',
    );

    await tester.enterText(find.byType(TextField), 'stalenestedtoken');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-global-search-result-${noteB.id}')),
      findsNothing,
      reason: 'nested detail refresh must remove the prior Body token',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
