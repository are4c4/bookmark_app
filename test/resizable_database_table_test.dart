import 'package:bookmark_app/features/database/presentation/widgets/resizable_database_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required Future<void> Function(String key, double width) onWidthCommitted,
  Map<String, dynamic> initialWidths = const <String, dynamic>{},
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ResizableDatabaseTable(
        columns: const [
          ResizableDatabaseTableColumn(
            keyName: 'title',
            label: Text('名前'),
            defaultWidth: 200,
            minWidth: 140,
            maxWidth: 320,
          ),
          ResizableDatabaseTableColumn(
            keyName: 'p:7',
            label: Text('メモ'),
            defaultWidth: 180,
            minWidth: 120,
            maxWidth: 300,
          ),
        ],
        rows: const [
          ResizableDatabaseTableRow(
            cells: [
              ResizableDatabaseTableCell(child: Text('Example')),
              ResizableDatabaseTableCell(child: Text('Long note')),
            ],
          ),
        ],
        initialWidths: initialWidths,
        onWidthCommitted: onWidthCommitted,
      ),
    ),
  ),
);

void main() {
  testWidgets('drag resizes column and commits only when drag ends', (
    tester,
  ) async {
    final commits = <(String, double)>[];
    await tester.pumpWidget(
      _host(onWidthCommitted: (key, width) async => commits.add((key, width))),
    );

    final column = find.byKey(
      const ValueKey<String>('database-table-column-title'),
    );
    final handle = find.byKey(
      const ValueKey<String>('database-table-resize-title'),
    );
    expect(tester.getSize(column).width, 200);

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(72, 0));
    await tester.pump();

    expect(tester.getSize(column).width, 272);
    expect(commits, isEmpty);

    await gesture.up();
    await tester.pump();

    expect(commits, hasLength(1));
    expect(commits.single.$1, 'title');
    expect(commits.single.$2, 272);
  });

  testWidgets('stored widths clamp and malformed values use defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        initialWidths: const <String, dynamic>{
          'title': 9999,
          'p:7': 'old-format',
        },
        onWidthCommitted: (_, __) async {},
      ),
    );

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('database-table-column-title')),
          )
          .width,
      320,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('database-table-column-p:7')),
          )
          .width,
      180,
    );
  });

  testWidgets('resize handle exposes keyboard shortcuts and resize cursor', (
    tester,
  ) async {
    await tester.pumpWidget(_host(onWidthCommitted: (_, __) async {}));

    final handle = find.byKey(
      const ValueKey<String>('database-table-resize-title'),
    );
    final mouseRegion = tester.widget<MouseRegion>(
      find.ancestor(of: handle, matching: find.byType(MouseRegion)).first,
    );
    expect(mouseRegion.cursor, SystemMouseCursors.resizeColumn);

    final focusable = tester.widget<FocusableActionDetector>(
      find
          .ancestor(of: handle, matching: find.byType(FocusableActionDetector))
          .first,
    );
    expect(focusable.shortcuts, isNotEmpty);
  });
}
