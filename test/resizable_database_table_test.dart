import 'dart:async';

import 'package:bookmark_app/features/database/presentation/widgets/resizable_database_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('same columns adopt changed external persisted widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        initialWidths: const <String, dynamic>{'title': 216, 'p:7': 224},
        onWidthCommitted: (_, __) async {},
      ),
    );

    final title = find.byKey(
      const ValueKey<String>('database-table-column-title'),
    );
    final note = find.byKey(
      const ValueKey<String>('database-table-column-p:7'),
    );
    expect(tester.getSize(title).width, 216);
    expect(tester.getSize(note).width, 224);

    await tester.pumpWidget(
      _host(
        initialWidths: const <String, dynamic>{'title': 304, 'p:7': 144},
        onWidthCommitted: (_, __) async {},
      ),
    );
    await tester.pump();

    expect(tester.getSize(title).width, 304);
    expect(tester.getSize(note).width, 144);
  });

  testWidgets('resize handle supports focused keyboard resizing', (
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
    final mouseRegion = tester.widget<MouseRegion>(
      find.ancestor(of: handle, matching: find.byType(MouseRegion)).first,
    );
    expect(mouseRegion.cursor, SystemMouseCursors.resizeColumn);

    await tester.tap(handle);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(tester.getSize(column).width, 216);
    expect(commits, <(String, double)>[('title', 216)]);
  });

  testWidgets('rapid keyboard commits stay ordered and keep latest local width', (
    tester,
  ) async {
    final firstRelease = Completer<void>();
    final started = <double>[];
    await tester.pumpWidget(
      _host(
        onWidthCommitted: (key, width) async {
          started.add(width);
          if (started.length == 1) await firstRelease.future;
        },
      ),
    );

    final column = find.byKey(
      const ValueKey<String>('database-table-column-title'),
    );
    final handle = find.byKey(
      const ValueKey<String>('database-table-resize-title'),
    );
    await tester.tap(handle);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(tester.getSize(column).width, 232);
    expect(started, <double>[216]);

    firstRelease.complete();
    await tester.pump();
    await tester.pump();

    expect(started, <double>[216, 232]);
  });
}
