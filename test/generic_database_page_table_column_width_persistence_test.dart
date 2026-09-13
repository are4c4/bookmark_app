import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/database_view_table_column_widths_adapter.dart';
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
  testWidgets(
    'real Table host persists resized title width and restores it after recreation',
    (tester) async {
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
      final weblinks = WeblinkObjectService(
        systemObjects: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      await weblinks.findOrCreate(
        workspaceId: workspaceId,
        url: 'https://example.com/resizable-table',
        title: 'Resizable table article',
      );
      final definition = await weblinks.ensureDefinition(workspaceId);
      final destination = (await genericStore.listDatabases(workspaceId))
          .singleWhere((item) => item.id == definition.objectType.id);
      final viewStore = DatabaseViewStore(database);
      final databaseKey = destination.databaseKey;

      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pumpHost() => tester.pumpWidget(
        MaterialApp(
          home: GenericDatabasePage(
            repository: repository,
            databaseId: destination.id,
            onDatabaseChanged: () {},
          ),
        ),
      );

      Future<List<DatabaseViewConfig>> waitForViews() async {
        for (var attempt = 0; attempt < 40; attempt += 1) {
          await tester.pump(const Duration(milliseconds: 50));
          final views = await viewStore.listViews(
            workspaceId: workspaceId,
            databaseKey: databaseKey,
          );
          if (views.isNotEmpty) return views;
        }
        return viewStore.listViews(
          workspaceId: workspaceId,
          databaseKey: databaseKey,
        );
      }

      Future<void> pumpUntilVisible(Finder finder) async {
        if (finder.evaluate().isNotEmpty) return;
        for (var attempt = 0; attempt < 40; attempt += 1) {
          await tester.pump(const Duration(milliseconds: 50));
          if (finder.evaluate().isNotEmpty) return;
        }
        expect(finder, findsWidgets);
      }

      Future<DatabaseViewConfig> waitForPersistedWidth() async {
        for (var attempt = 0; attempt < 40; attempt += 1) {
          await tester.pump(const Duration(milliseconds: 50));
          final view = (await viewStore.listViews(
            workspaceId: workspaceId,
            databaseKey: databaseKey,
          ))
              .single;
          final raw = view.settings[
            DatabaseViewTableColumnWidthsAdapter.settingsKey
          ];
          if (raw is Map && raw['title'] is num) return view;
        }
        return (await viewStore.listViews(
          workspaceId: workspaceId,
          databaseKey: databaseKey,
        ))
            .single;
      }

      await pumpHost();
      final seeded = (await waitForViews()).single;
      await viewStore.updateView(
        seeded.copyWith(
          name: 'Resizable Table',
          layoutType: 'table',
          settings: const <String, dynamic>{'unrelated': 'keep'},
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpHost();

      final titleColumn = find.byKey(
        const ValueKey<String>('database-table-column-title'),
      );
      final resizeHandle = find.byKey(
        const ValueKey<String>('database-table-resize-title'),
      );
      await pumpUntilVisible(resizeHandle);
      expect(tester.getSize(titleColumn).width, 240);

      final gesture = await tester.startGesture(tester.getCenter(resizeHandle));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(64, 0));
      await tester.pump();
      expect(tester.getSize(titleColumn).width, 304);

      await gesture.up();
      await tester.pump();

      final persisted = await waitForPersistedWidth();
      expect(persisted.settings['unrelated'], 'keep');
      final widths = persisted.settings[
        DatabaseViewTableColumnWidthsAdapter.settingsKey
      ] as Map;
      expect((widths['title'] as num).toDouble(), 304);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpHost();
      await pumpUntilVisible(titleColumn);

      expect(tester.getSize(titleColumn).width, 304);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
