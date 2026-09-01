import 'package:bookmark_app/features/database/presentation/widgets/database_page_toolbar.dart';
import 'package:bookmark_app/widgets/database_create_tiles.dart';
import 'package:bookmark_app/widgets/detail_property_row.dart';
import 'package:bookmark_app/widgets/resizable_detail_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('property value area invokes the same add action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: DetailPropertyRow(
              icon: Icons.sell_outlined,
              label: 'タグ',
              child: const Text('なし'),
              onAdd: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('なし'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('property rows keep handle and label columns aligned', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                DetailPropertyRow(
                  icon: Icons.sell_outlined,
                  label: 'タグ',
                  dragHandle: Icon(Icons.drag_indicator, size: 15),
                  child: Text('エンタメ'),
                ),
                DetailPropertyRow(
                  icon: Icons.person_outline,
                  label: '出演者',
                  dragHandle: Icon(Icons.drag_indicator, size: 15),
                  child: Text('今田耕司'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final handles = find.byKey(const ValueKey('detail-property-handle-column'));
    final labels = find.byKey(const ValueKey('detail-property-label-column'));
    expect(handles, findsNWidgets(2));
    expect(labels, findsNWidgets(2));

    final firstHandle = tester.getTopLeft(handles.at(0));
    final secondHandle = tester.getTopLeft(handles.at(1));
    final firstLabel = tester.getTopLeft(labels.at(0));
    final secondLabel = tester.getTopLeft(labels.at(1));

    expect(firstHandle.dx, secondHandle.dx);
    expect(firstLabel.dx, secondLabel.dx);
    expect(tester.getSize(handles.at(0)).width, DetailPropertyRow.handleColumnWidth);
    expect(tester.getSize(labels.at(0)).width, DetailPropertyRow.labelColumnWidth);
  });

  testWidgets('database create card creates item with Enter', (tester) async {
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: DatabaseCreateCard(
              label: '新しい人物',
              onCreate: (value) async => created = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('新しい人物'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '山口一郎（サカナクション）');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(created, '山口一郎（サカナクション）');
  });

  testWidgets('resizable detail pane reacts to horizontal drag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: ResizableDetailPane(
              storageKey: 'test-detail-pane',
              initialWidth: 400,
              child: SizedBox.expand(key: ValueKey('detail-content')),
            ),
          ),
        ),
      ),
    );

    final before = tester.getSize(find.byKey(const ValueKey('detail-content'))).width;
    final divider = find.byType(GestureDetector).first;
    await tester.drag(divider, const Offset(-60, 0));
    await tester.pump();
    final after = tester.getSize(find.byKey(const ValueKey('detail-content'))).width;

    expect(after, greaterThan(before));
  });

  testWidgets('database toolbar uses compact layout menu and expandable search', (tester) async {
    var layout = 'gallery';
    var query = '';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: DatabasePageToolbar(
              leadingActions: const [TextButton(onPressed: null, child: Text('フィルター'))],
              layoutType: layout,
              supportedLayouts: const ['gallery', 'table', 'list'],
              onLayoutChanged: (value) => setState(() => layout = value),
              searchHint: '検索',
              searchValue: query,
              onSearchChanged: (value) => query = value,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('database-search-expanded')), findsNothing);
    expect(find.text('ギャラリー'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('database-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('database-search-expanded')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Notion');
    await tester.pump();
    expect(query, 'Notion');
  });
}
