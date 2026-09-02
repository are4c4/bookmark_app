import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:bookmark_app/features/database/presentation/widgets/database_view_tabs.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('View settings persist and clear Object opening mode override',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = DatabaseViewStore(database);
    const definition = DatabaseDefinition(
      key: 'custom:notes',
      label: 'Notes',
      icon: Icons.note_outlined,
      properties: <DatabasePropertyDefinition>[],
      defaultLayout: 'list',
      supportedLayouts: <String>['list'],
    );
    final viewId = await store.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'すべて',
    );
    DatabaseViewConfig? selected;

    Future<void> pumpTabs() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: DatabaseViewTabs(
                store: store,
                definition: definition,
                workspaceId: workspaceId,
                activeViewId: viewId,
                onSelected: (view) => selected = view,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpTabs();
    await tester.tap(find.byKey(ValueKey('database-view-menu-$viewId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Objectの開き方'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('フルページ'));
    await tester.pumpAndSettle();

    var view = (await store.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .single;
    expect(view.settings['openMode'], ObjectOpenMode.fullPage.name);
    expect(selected?.settings['openMode'], ObjectOpenMode.fullPage.name);

    await tester.tap(find.byKey(ValueKey('database-view-menu-$viewId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Objectの開き方'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('継承（デフォルト）'));
    await tester.pumpAndSettle();

    view = (await store.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .single;
    expect(view.settings.containsKey('openMode'), isFalse);
  });
}
