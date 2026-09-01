import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/views/tag_tree_model.dart';
import 'package:bookmark_app/widgets/tag_tree_view.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('selected tag exposes add child action', (tester) async {
    Tag? requestedParent;
    await _pumpTagTree(
      tester,
      brightness: Brightness.light,
      textColor: Colors.black,
      selectedTagId: 1,
      onAddChild: (tag) => requestedParent = tag,
    );

    final addButton = find.byKey(const ValueKey('add-child-tag:1'));
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pump();

    expect(requestedParent?.id, 1);
  });

  testWidgets('group row exposes contextual add action on hover', (tester) async {
    int? requestedGroup = 999;
    await _pumpTagTree(
      tester,
      brightness: Brightness.light,
      textColor: Colors.black,
      includeGroup: true,
      onAddToGroup: (groupId) => requestedGroup = groupId,
    );

    await tester.sendEventToBinding(
      const PointerHoverEvent(position: Offset(80, 18)),
    );
    await tester.pump();

    final addButton = find.byKey(const ValueKey('add-group-tag:-1'));
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pump();

    expect(requestedGroup, isNull);
  });

  testWidgets('inline create row renders below requested parent', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpTagTree(
      tester,
      brightness: Brightness.light,
      textColor: Colors.black,
      creatingUnderKey: 'tag:1',
      createController: controller,
    );

    expect(find.byKey(const ValueKey('inline-create:tag:1')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}

Future<void> _pumpTagTree(
  WidgetTester tester, {
  required Brightness brightness,
  required Color textColor,
  int? selectedTagId,
  bool includeGroup = false,
  ValueChanged<Tag>? onAddChild,
  ValueChanged<int?>? onAddToGroup,
  String? creatingUnderKey,
  TextEditingController? createController,
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
      if (includeGroup)
        const TagTreeRow.group(
          groupId: null,
          label: 'その他タグ',
          expanded: true,
          hasChildren: true,
        ),
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
      key: ValueKey(brightness),
      theme: ThemeData(colorScheme: scheme),
      home: Scaffold(
        body: TagTreeView(
          model: model,
          query: '',
          selectedTagId: selectedTagId,
          focusedKey: null,
          multiSelectedIds: const {},
          creatingUnderKey: creatingUnderKey,
          createController: createController,
          onAddChild: onAddChild,
          onAddToGroup: onAddToGroup,
          onSubmitCreate: () {},
          onCancelCreate: () {},
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
