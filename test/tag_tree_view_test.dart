import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/views/tag_tree_model.dart';
import 'package:bookmark_app/widgets/tag_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tag text uses the theme onSurface color', (tester) async {
    const lightTextColor = Color(0xff123456);
    const darkTextColor = Color(0xfff0e0d0);

    await _pumpTagTree(
      tester,
      brightness: Brightness.light,
      textColor: lightTextColor,
    );
    expect(_tagText(tester).text.style?.color, lightTextColor);

    await _pumpTagTree(
      tester,
      brightness: Brightness.dark,
      textColor: darkTextColor,
    );
    expect(_tagText(tester).text.style?.color, darkTextColor);
  });
}

Future<void> _pumpTagTree(
  WidgetTester tester, {
  required Brightness brightness,
  required Color textColor,
}) async {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: brightness,
  ).copyWith(onSurface: textColor);
  final tag = Tag(
    id: 1,
    name: 'Visible Tag',
    parentTagId: null,
    groupId: null,
    createdAt: DateTime.utc(2026),
  );
  final model = TagTreeModel(
    rows: [
      TagTreeRow.tag(
        tag: tag,
        depth: 0,
        expanded: false,
        hasChildren: false,
        directCount: 0,
        aggregateCount: 0,
        searchMatch: true,
      ),
    ],
    matchingTagIds: const {1},
    allowedTagIds: const {1},
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: scheme),
      home: Scaffold(
        body: TagTreeView(
          model: model,
          query: '',
          selectedTagId: null,
          focusedKey: null,
          multiSelectedIds: const {},
          onSelectTag: (_) {},
          onFocusRow: (_) {},
          onToggleGroup: (_) {},
          onToggleTag: (_) {},
          onToggleMultiSelect: (_) {},
          onBeginRename: (_) {},
          onSubmitRename: (_) {},
          onCancelRename: () {},
          onMenuAction: (_, _) {},
          onDrop: (_, _) {},
          canDrop: (_, _) => true,
          onShowDirect: (_) {},
          onShowAggregate: (_) {},
          onDragStarted: (_) {},
          onDragEnded: () {},
        ),
      ),
    ),
  );
}

RichText _tagText(WidgetTester tester) => tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'Visible Tag',
      ),
    );
