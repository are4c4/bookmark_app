import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/features/database/presentation/widgets/database_view_tabs.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plus duplicates active View and menu creates a blank View',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = DatabaseViewStore(database);
    const definition = DatabaseDefinition(
      key: 'custom:books',
      label: 'Books',
      icon: Icons.menu_book_outlined,
      properties: <DatabasePropertyDefinition>[
        DatabasePropertyDefinition(
          key: 'title',
          label: 'Title',
          type: DatabasePropertyType.text,
          icon: Icons.title,
        ),
      ],
      defaultLayout: 'table',
      supportedLayouts: <String>['table', 'gallery'],
    );
    final sourceId = await store.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: '読書中',
      layoutType: 'gallery',
      filters: const <String, dynamic>{'query': 'Serre'},
      settings: const <String, dynamic>{'openMode': 'sidePeek'},
    );
    DatabaseViewConfig? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            child: DatabaseViewTabs(
              store: store,
              definition: definition,
              workspaceId: workspaceId,
              activeViewId: sourceId,
              onSelected: (view) => selected = view,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('database-view-add-button')));
    await tester.pumpAndSettle();

    var views = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    expect(views, hasLength(2));
    final duplicate = views.last;
    expect(duplicate.name, '読書中 のコピー');
    expect(duplicate.layoutType, 'gallery');
    expect(duplicate.filters, const <String, dynamic>{'query': 'Serre'});
    expect(duplicate.settings, const <String, dynamic>{'openMode': 'sidePeek'});
    expect(selected?.id, duplicate.id);

    await tester.tap(find.byKey(const ValueKey('database-view-create-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('空のViewを作成'));
    await tester.pumpAndSettle();

    views = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    expect(views, hasLength(3));
    final blank = views.last;
    expect(blank.name, '新しいビュー');
    expect(blank.layoutType, definition.defaultLayout);
    expect(blank.filters, isEmpty);
    expect(blank.sorts, isEmpty);
    expect(blank.settings, isEmpty);
    expect(selected?.id, blank.id);
  });
}
