import 'package:bookmark_app/services/profile_manager.dart';
import 'package:bookmark_app/views/profile_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile management presents the product concept as Vault',
      (tester) async {
    const state = ProfileState(
      profiles: <DatabaseProfile>[
        DatabaseProfile(
          id: 'default',
          name: 'Default',
          databaseName: 'BookmarkApp/Profiles/default/database',
          directoryPath: '/managed/default',
        ),
        DatabaseProfile(
          id: 'external',
          name: 'External Vault',
          databaseName: 'BookmarkApp/Profiles/external/database',
          directoryPath: '/external/bookmark-vault',
        ),
      ],
      activeProfileId: 'default',
    );

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileManagementPage(
          state: state,
          onSwitch: (_) async {},
          onCreate: (_) async {},
          onRename: (_, __) async {},
          onDuplicate: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.text('Vault管理'), findsOneWidget);
    expect(find.text('Vaultを追加'), findsOneWidget);
    expect(find.text('Profile管理'), findsNothing);
    expect(find.text('Profileを追加'), findsNothing);
  });

  testWidgets('Vault removal clearly preserves the Vault folder and data',
      (tester) async {
    const state = ProfileState(
      profiles: <DatabaseProfile>[
        DatabaseProfile(
          id: 'default',
          name: 'Default',
          databaseName: 'BookmarkApp/Profiles/default/database',
          directoryPath: '/managed/default',
        ),
        DatabaseProfile(
          id: 'external',
          name: 'External Vault',
          databaseName: 'BookmarkApp/Profiles/external/database',
          directoryPath: '/external/bookmark-vault',
        ),
      ],
      activeProfileId: 'default',
    );
    var removed = false;

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileManagementPage(
          state: state,
          onSwitch: (_) async {},
          onCreate: (_) async {},
          onRename: (_, __) async {},
          onDuplicate: (_) async {},
          onDelete: (_) async => removed = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('一覧から外す'));
    await tester.pumpAndSettle();

    expect(find.text('「External Vault」を一覧から外しますか？'), findsOneWidget);
    expect(
      find.textContaining('Vaultフォルダと保存データは削除されません'),
      findsOneWidget,
    );
    expect(
      find.textContaining('既存のVaultとして再度開けます'),
      findsOneWidget,
    );
    expect(
      find.textContaining('保存データも削除されます'),
      findsNothing,
    );

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(removed, isFalse);
  });
}
