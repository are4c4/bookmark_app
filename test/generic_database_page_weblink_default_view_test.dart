import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/database/presentation/widgets/system_object_list_media.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'zero-View Weblinks open in shared List and preserve later customization',
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
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final weblinks = WeblinkObjectService(
        systemObjects: systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      final weblink = await weblinks.findOrCreate(
        workspaceId: workspaceId,
        url: 'https://example.com/article',
        title: 'Canonical Weblink row',
      );
      final definition = await weblinks.ensureDefinition(workspaceId);
      final destination = (await genericStore.listDatabases(workspaceId))
          .singleWhere((item) => item.id == definition.objectType.id);
      final viewStore = DatabaseViewStore(database);
      expect(
        await viewStore.listViews(
          workspaceId: workspaceId,
          databaseKey: destination.databaseKey,
        ),
        isEmpty,
      );

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pumpPage() async {
        await tester.pumpWidget(
          MaterialApp(
            home: GenericDatabasePage(
              repository: repository,
              databaseId: destination.id,
              onDatabaseChanged: () {},
            ),
          ),
        );
      }

      await pumpPage();

      final listMediaHost = find.byWidgetPredicate(
        (widget) =>
            widget is SystemObjectListMedia &&
            widget.workspaceId == workspaceId &&
            widget.objectTypeId == definition.objectType.id &&
            widget.objectId == weblink.id &&
            widget.size == 36,
        description: 'canonical Weblink shared List media host',
      );
      await pumpUntilVisible(listMediaHost);
      expect(find.text('Canonical Weblink row'), findsOneWidget);

      var views = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: destination.databaseKey,
      );
      expect(views, hasLength(1));
      expect(views.single.name, 'リスト');
      expect(views.single.layoutType, 'list');

      final customized = views.single.copyWith(
        name: 'My Gallery',
        layoutType: 'gallery',
        settings: const <String, dynamic>{'customized': true},
      );
      await viewStore.updateView(customized);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpPage();
      await tester.pumpAndSettle();

      views = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: destination.databaseKey,
      );
      expect(views, hasLength(1));
      expect(views.single.id, customized.id);
      expect(views.single.name, 'My Gallery');
      expect(views.single.layoutType, 'gallery');
      expect(views.single.settings, const <String, dynamic>{'customized': true});

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
