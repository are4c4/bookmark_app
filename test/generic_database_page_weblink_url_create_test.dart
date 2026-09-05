import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<({
    AppDatabase database,
    BookmarkRepository repository,
    ObjectStore objectStore,
    SystemObjectStore systemObjects,
    ObjectTypeDefaultsStore defaultsStore,
    int workspaceId,
  })> buildFixture() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    return (
      database: database,
      repository: repository,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
      workspaceId: workspaceId,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required BookmarkRepository repository,
    required int databaseId,
  }) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GenericDatabasePage(
          repository: repository,
          databaseId: databaseId,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpFiniteAsyncUi(WidgetTester tester) async {
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> submitUrl(WidgetTester tester, String url) async {
    await tester.tap(find.text('URLを追加').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('weblink-url-create-input')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('weblink-url-create-input')),
      url,
    );
    await tester.tap(find.byKey(const ValueKey('weblink-url-create-submit')));
    await pumpFiniteAsyncUi(tester);
  }

  testWidgets(
    'real Weblinks page creates and reuses canonical Weblink from URL entry',
    (tester) async {
      final fixture = await buildFixture();
      addTearDown(fixture.database.close);
      final definition = await WeblinkObjectService(
        systemObjects: fixture.systemObjects,
        defaultsStore: fixture.defaultsStore,
      ).ensureDefinition(fixture.workspaceId);

      await pumpPage(
        tester,
        repository: fixture.repository,
        databaseId: definition.objectType.id,
      );

      expect(find.text('URLを追加'), findsOneWidget);
      expect(
        await fixture.objectStore.listObjects(definition.objectType.id),
        isEmpty,
      );

      await submitUrl(
        tester,
        'HTTPS://Example.COM:443/articles/../guide',
      );

      var objects =
          await fixture.objectStore.listObjects(definition.objectType.id);
      expect(objects, hasLength(1));
      final canonicalId = objects.single.id;
      expect(objects.single.title, 'example.com');
      expect(
        objects.single.values[definition.urlProperty.id],
        'https://example.com/guide',
      );
      expect(find.text('example.com'), findsWidgets);

      await submitUrl(tester, 'https://example.com/guide');

      objects = await fixture.objectStore.listObjects(definition.objectType.id);
      expect(objects, hasLength(1));
      expect(objects.single.id, canonicalId);
      expect(
        objects.single.values[definition.urlProperty.id],
        'https://example.com/guide',
      );
    },
  );
}
