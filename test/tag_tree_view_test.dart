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
    final iconButton = tester.widget<IconButton>(addButton);
    expect(iconButton.onPressed, isNotNull);
    iconButton.onPressed!.call();
    await tester.pump();

    expect(requestedParent?.id, 1);
  });

  testWidgets('focused group exposes contextual add action', (tester) async {
    int? requestedGroup = 999;
    await _pumpTagTree(
      tester,
      brightness: Brightness.light,
      textColor: Colors.black,
      includeGroup: true,
      focusedKey: 'group:other',
      onAddToGroup: (groupId) => requestedGroup = groupId,
    );

    final addButton = find.byKey(const ValueKey('add-group-tag:-1'));
    expect(addButton, findsOneWidget);
    final iconButton = tester.widget<IconButton>(addButton);
    expect(iconButton.onPressed, isNotNull);
    iconButton.onPressed!.call();
    await tester.pump();

    expect(requestedGroup, isNull);
  });

  testWidgets('persisted group menu exposes rename and delete callbacks',
      (tester) async {
    final actions = <String>[];
    await _pumpTagTree(
      tester,
      brightness: Brightness.light,
      textColor: Colors.black,
      includeGroup: true,
      persistedGroupId: 7,
      focusedKey: 'group:7',
      onGroupMenuAction: (groupId, action) {
        actions.add('$groupId:$action');
      },
    );

    final menu = find.byKey(const ValueKey('tag-group-menu:7'));
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await tester.pump();
    expect(find.text('名前変更'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);

    await tester.tap(find.text('名前変更'));
    await tester.pump();
    expect(actions, ['7:rename']);

    await tester.tap(menu);
    await tester.pump();
    await tester.tap(find.text('削除'));
    await tester.pump();
    expect(actions, ['7:rename', '7:delete']);
  });

  testWidgets('synthetic other group omits rename and delete actions',
      (tester) async {
    await _pumpTagTree(
      tester,
      brightness: Brightness.light,
      textColor: Colors.black,
      includeGroup: true,
      focusedKey: 'group:other',
    );

    await tester.tap(find.byKey(const ValueKey('tag-group-menu:-1')));
    await tester.pump();

    expect(find.text('タグを追加'), findsOneWidget);
    expect(find.text('名前変更'), findsNothing);
    expect(find.text('削除'), findsNothing);
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
  String? focusedKey,
  bool includeGroup = false,
  int? persistedGroupId,
  ValueChanged<Tag>? onAddChild,
  ValueChanged<int?>? onAddToGroup,
  void Function(int? groupId, String action)? onGroupMenuAction,
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
        TagTreeRow.group(
          groupId: persistedGroupId,
          label: persistedGroupId == null ? 'その他タグ' : '属性',
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
          focusedKey: focusedKey,
          multiSelectedIds: const {},
          creatingUnderKey: creatingUnderKey,
          createController: createController,
          onAddChild: onAddChild,
          onAddToGroup: onAddToGroup,
          onGroupMenuAction: onGroupMenuAction,
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
