import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/canonical_weblink_capture_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/home_start_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows canonical recently changed Objects with ObjectType context',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final store = GenericDatabaseStore(database);
      final objectStore = ObjectStore(store);
      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Papers',
        icon: '📄',
      );
      final objectId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Local fields',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeStartPage(store: store, workspaceId: workspaceId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ホーム'), findsOneWidget);
      expect(find.text('最近のオブジェクト'), findsOneWidget);
      expect(find.text('Local fields'), findsOneWidget);
      expect(find.textContaining('Papers'), findsOneWidget);
      expect(
        find.byKey(ValueKey('home-recent-object-$objectId')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows a useful empty state without inventing Home-only data', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartPage(store: store, workspaceId: workspaceId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近更新したオブジェクトはありません。'), findsOneWidget);
    expect(find.text('Inbox'), findsNothing);
    expect(find.text('Favorites'), findsNothing);
    expect(find.text('Pinned Databases'), findsNothing);
  });

  testWidgets(
    'quick capture creates a canonical Weblink without Bookmark data',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final harness = _HomeWeblinkHarness(database);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeStartPage(store: harness.store, workspaceId: workspaceId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('home-weblink-url-field')),
        'https://example.com/home-capture',
      );
      await tester.tap(
        find.byKey(const ValueKey('home-weblink-capture-button')),
      );
      await tester.pumpAndSettle();

      final definition = await harness.weblinks.ensureDefinition(workspaceId);
      final objects =
          await harness.objectStore.listObjects(definition.objectType.id);
      final bookmarkCount = await database
          .customSelect('SELECT COUNT(*) AS count FROM bookmarks')
          .getSingle();

      expect(objects, hasLength(1));
      expect(bookmarkCount.read<int>('count'), 0);
      expect(
        find.byKey(const ValueKey('home-weblink-open-result')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('home-recent-object-${objects.single.id}')),
        findsOneWidget,
      );
    },
  );

  testWidgets('keyboard capture reuses identity without forging updatedAt', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final harness = _HomeWeblinkHarness(database);
    final original = await harness.capture.capture(
      workspaceId: workspaceId,
      url: 'https://example.com/reused',
    );
    final definition = await harness.weblinks.ensureDefinition(workspaceId);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartPage(
          store: harness.store,
          workspaceId: workspaceId,
          recentLimit: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('home-weblink-url-field')),
      'HTTPS://Example.COM:443/reused',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final objects =
        await harness.objectStore.listObjects(definition.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.id, original.id);
    expect(objects.single.updatedAt, original.updatedAt);
    expect(
      find.byKey(const ValueKey('home-weblink-open-result')),
      findsOneWidget,
    );
  });

  testWidgets('invalid quick capture fails closed with stable UI error', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final harness = _HomeWeblinkHarness(database);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartPage(store: harness.store, workspaceId: workspaceId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('home-weblink-url-field')),
      'example.com/no-scheme',
    );
    await tester.tap(
      find.byKey(const ValueKey('home-weblink-capture-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('このURLを保存できませんでした。URLを確認してください。'),
      findsOneWidget,
    );
    expect(
      await harness.systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
      ),
      isNull,
    );
  });
}

class _HomeWeblinkHarness {
  _HomeWeblinkHarness(AppDatabase database) {
    store = GenericDatabaseStore(database);
    objectStore = ObjectStore(store);
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(store),
    );
    capture = CanonicalWeblinkCaptureService(weblinks: weblinks);
  }

  late final GenericDatabaseStore store;
  late final ObjectStore objectStore;
  late final SystemObjectStore systemObjects;
  late final WeblinkObjectService weblinks;
  late final CanonicalWeblinkCaptureService capture;
}
