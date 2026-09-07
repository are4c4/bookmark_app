import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/features/database/presentation/widgets/system_object_list_media.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real Images List hosts canonical Image leading media',
      (tester) async {
    Future<void> pumpUntilVisible(Finder finder) async {
      if (finder.evaluate().isNotEmpty) return;
      for (var attempt = 0; attempt < 30; attempt += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
      }
      expect(finder, findsWidgets);
    }

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
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
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final objectId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Canonical Image row',
    );

    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: DatabaseDefinition(
        key: 'custom:${definition.objectType.id}',
        label: 'Images',
        icon: Icons.image_outlined,
        properties: const <DatabasePropertyDefinition>[],
        defaultLayout: 'list',
        supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
      ),
      name: 'List',
      layoutType: 'list',
    );

    final destination = (await genericStore.listDatabases(workspaceId))
        .singleWhere((item) => item.id == definition.objectType.id);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GenericDatabasePage(
          repository: repository,
          databaseId: destination.id,
          onDatabaseChanged: () {},
        ),
      ),
    );

    // The Images system collection can briefly expose its default Table while
    // the persisted List View is loading. Wait for the List-specific 36px host
    // instead of accepting the same Object's Table media at 32px.
    final host = find.byWidgetPredicate(
      (widget) =>
          widget is SystemObjectListMedia &&
          widget.workspaceId == workspaceId &&
          widget.objectTypeId == definition.objectType.id &&
          widget.objectId == objectId &&
          widget.size == 36,
      description: 'canonical Image List media host',
    );
    await pumpUntilVisible(host);
    expect(host, findsOneWidget);
    expect(
      find.byKey(ValueKey('system-object-list-media-image-$objectId')),
      findsOneWidget,
    );
    expect(find.text('Canonical Image row'), findsOneWidget);

    final hostedMedia = tester.widget<SystemObjectListMedia>(host);
    expect(hostedMedia.database, same(database));
    expect(hostedMedia.size, 36);

    // This real-page regression deliberately uses a canonical Image without a
    // File value so the production resolver can complete without starting a
    // platform Image.file decode. Dedicated ImageVisualResolver tests already
    // cover managed PNG/path resolution, while SystemObjectListMedia tests
    // cover resolved-file presentation through the injected image builder.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
