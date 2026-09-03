import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/daily_note_navigation_bar.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Daily Note inspector navigates dates and keeps Body editable',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final dailyNotes = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    final note = await dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 3),
    );

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: note.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DailyNoteNavigationBar), findsOneWidget);
    expect(find.text('2026-09-03'), findsWidgets);
    expect(find.byKey(const ValueKey('body-empty-insert')), findsOneWidget);

    await tester.tap(find.byTooltip('次の日'));
    await tester.pumpAndSettle();

    expect(find.byType(DailyNoteNavigationBar), findsOneWidget);
    expect(find.text('2026-09-04'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('body-empty-insert')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('テキスト').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('body-text-paragraph-1')),
      '翌日のメモ',
    );
    await tester.pumpAndSettle();

    final next = await dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 4),
    );
    final body = await bodyStore.read(next.id);
    expect(body.blocks, hasLength(1));
    expect(body.blocks.single.text, '翌日のメモ');
  });
}
