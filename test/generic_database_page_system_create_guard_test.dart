import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
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

  testWidgets('real Weblinks page refuses title-only generic creation',
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
    expect(await fixture.objectStore.listObjects(definition.objectType.id), isEmpty);

    await tester.tap(find.text('新規ページ').last);
    await tester.pumpAndSettle();

    expect(await fixture.objectStore.listObjects(definition.objectType.id), isEmpty);
    expect(find.textContaining('Weblinks must be created from a URL'), findsOneWidget);
  });

  testWidgets('real Images page refuses title-only generic creation',
      (tester) async {
    final fixture = await buildFixture();
    addTearDown(fixture.database.close);
    final definition = await ImageObjectService(
      systemObjects: fixture.systemObjects,
      defaultsStore: fixture.defaultsStore,
    ).ensureDefinition(fixture.workspaceId);

    await pumpPage(
      tester,
      repository: fixture.repository,
      databaseId: definition.objectType.id,
    );
    expect(await fixture.objectStore.listObjects(definition.objectType.id), isEmpty);

    await tester.tap(find.text('新規ページ').last);
    await tester.pumpAndSettle();

    expect(await fixture.objectStore.listObjects(definition.objectType.id), isEmpty);
    expect(
      find.textContaining('Images must be created from managed image/file input'),
      findsOneWidget,
    );
  });
}
