import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/features/database/presentation/widgets/database_view_tabs.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('many Views expose fixed その他 selection', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = DatabaseViewStore(database);
    const definition = DatabaseDefinition(
      key: 'custom:overflow',
      label: 'Overflow',
      icon: Icons.table_chart_outlined,
      properties: <DatabasePropertyDefinition>[],
      defaultLayout: 'table',
      supportedLayouts: <String>['table'],
    );

    final ids = <int>[];
    for (var index = 1; index <= 8; index++) {
      ids.add(
        await store.createView(
          workspaceId: workspaceId,
          definition: definition,
          name: 'View $index',
          layoutType: 'table',
        ),
      );
    }
    DatabaseViewConfig? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: DatabaseViewTabs(
              store: store,
              definition: definition,
              workspaceId: workspaceId,
              activeViewId: ids.last,
              onSelected: (view) => selected = view,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Partition behavior (including active-View promotion) is covered by the
    // pure policy tests. This widget regression intentionally avoids assuming
    // which lazily-built horizontal tab is inside a particular test viewport;
    // it verifies that overflow controls remain fixed and usable beside it.
    final overflowMenu =
        find.byKey(const ValueKey('database-view-overflow-menu'));
    expect(overflowMenu, findsOneWidget);

    await tester.tap(overflowMenu);
    await tester.pumpAndSettle();

    final view7Item = find.byKey(
      ValueKey('database-view-overflow-item-${ids[6]}'),
    );
    expect(view7Item, findsOneWidget);
    await tester.tap(view7Item);
    await tester.pumpAndSettle();

    expect(selected?.id, ids[6]);
  });
}
