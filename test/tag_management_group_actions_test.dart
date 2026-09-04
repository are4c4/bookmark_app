import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/tag_group_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/tag_management_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkRepository repository;
  late TagGroupStore groupStore;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    groupStore = TagGroupStore(database);
    await groupStore.initialize();
  });

  tearDown(() => database.close());

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: TagManagementPage(repository: repository)),
    );
    await pumpUi(tester);
  }

  testWidgets('empty persisted group can be renamed and deleted from tree row',
      (tester) async {
    final groupId = await groupStore.createGroup('属性');

    await pumpPage(tester);

    expect(find.text('属性'), findsOneWidget);

    await tester.tap(find.text('属性'));
    await pumpUi(tester);
    await tester.tap(find.byKey(ValueKey('tag-group-menu:$groupId')));
    await pumpUi(tester);
    await tester.tap(find.text('名前変更').last);
    await pumpUi(tester);

    final renameDialog = find.byType(AlertDialog);
    expect(renameDialog, findsOneWidget);
    final nameField = find.descendant(
      of: renameDialog,
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, '分類');
    await tester.tap(
      find.descendant(of: renameDialog, matching: find.text('保存')),
    );
    await pumpUi(tester);

    expect(find.text('分類'), findsOneWidget);
    expect((await groupStore.listGroups()).single.name, '分類');

    await tester.tap(find.text('分類'));
    await pumpUi(tester);
    await tester.tap(find.byKey(ValueKey('tag-group-menu:$groupId')));
    await pumpUi(tester);
    await tester.tap(find.text('削除').last);
    await pumpUi(tester);

    expect(find.text('「分類」を削除しますか？'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await pumpUi(tester);

    expect(await groupStore.listGroups(), isEmpty);
    expect(find.text('分類'), findsNothing);
  });
}
