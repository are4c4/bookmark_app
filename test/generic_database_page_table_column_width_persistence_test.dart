import 'dart:async';

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
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/features/database/presentation/widgets/resizable_database_table.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'real Table host persists widths and keeps delayed commits scoped to source View',
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
      final viewDefinition = DatabaseDefinition(
        key: databaseKey,
        label: destination.name,
        icon: Icons.table_chart_outlined,
        properties: const [],
        defaultLayout: 'table',
        supportedLayouts: const ['table'],
      );

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

      Future<void> pumpUntilTableView(int viewId) async {
        final table = find.byKey(ValueKey<String>('database-table-$viewId'));
        if (table.evaluate().isNotEmpty) return;
        for (var attempt = 0; attempt < 40; attempt += 1) {
          await tester.pump(const Duration(milliseconds: 50));
          if (table.evaluate().isNotEmpty) return;
        }
        expect(table, findsOneWidget);
      }

      Future<void> pumpUntilWidth(Finder finder, double expected) async {
        for (var attempt = 0; attempt < 40; attempt += 1) {
          if (finder.evaluate().isNotEmpty &&
              tester.getSize(finder).width == expected) {
            return;
          }
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(finder, findsWidgets);
        expect(tester.getSize(finder).width, expected);
      }

      Future<DatabaseViewConfig> waitForWidth(
        int viewId,
        double expected,
      ) async {
        for (var attempt = 0; attempt < 40; attempt += 1) {
          await tester.pump(const Duration(milliseconds: 50));
          final view = (await viewStore.listViews(
            workspaceId: workspaceId,
            databaseKey: databaseKey,
          )).singleWhere((candidate) => candidate.id == viewId);
          final raw =
              view.settings[DatabaseViewTableColumnWidthsAdapter.settingsKey];
          if (raw is Map && raw['title'] is num) {
            final width = (raw['title'] as num).toDouble();
            if (width == expected) return view;
          }
        }
        return (await viewStore.listViews(
          workspaceId: workspaceId,
          databaseKey: databaseKey,
        )).singleWhere((candidate) => candidate.id == viewId);
      }

      await pumpHost();
      final seeded = (await waitForViews()).single;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await viewStore.updateView(
        seeded.copyWith(
          name: 'Resizable Table',
          layoutType: 'table',
          settings: const <String, dynamic>{'unrelated': 'keep'},
        ),
      );
      final secondViewId = await viewStore.createView(
        workspaceId: workspaceId,
        definition: viewDefinition,
        name: 'Second Table',
        layoutType: 'table',
        settings: const <String, dynamic>{
          'second': 'keep',
          DatabaseViewTableColumnWidthsAdapter.settingsKey: <String, dynamic>{
            'title': 200.0,
          },
        },
      );

      await pumpHost();

      final titleColumn = find.byKey(
        const ValueKey<String>('database-table-column-title'),
      );
      final resizeHandle = find.byKey(
        const ValueKey<String>('database-table-resize-title'),
      );
      final seededViewTab = find.text('Resizable Table');
      await pumpUntilVisible(seededViewTab);
      await tester.tap(seededViewTab);
      await tester.pump();
      await pumpUntilTableView(seeded.id);
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

      final persisted = await waitForWidth(seeded.id, 304);
      expect(persisted.settings['unrelated'], 'keep');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpHost();
      final persistedViewTab = find.text('Resizable Table');
      await pumpUntilVisible(persistedViewTab);
      await tester.tap(persistedViewTab);
      await tester.pump();
      await pumpUntilTableView(seeded.id);

      final reopened = (await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: databaseKey,
      )).singleWhere((candidate) => candidate.id == seeded.id);
      expect(
        (DatabaseViewTableColumnWidthsAdapter().decode(reopened)['title']
                as num)
            .toDouble(),
        304,
      );
      final table = tester.widget<ResizableDatabaseTable>(
        find.byType(ResizableDatabaseTable),
      );
      expect(table.key, ValueKey<String>('database-table-${seeded.id}'));
      expect((table.initialWidths['title'] as num).toDouble(), 304);
      await pumpUntilWidth(titleColumn, 304);

      final lockEntered = Completer<void>();
      final releaseLock = Completer<void>();
      final lockFuture = database.transaction(() async {
        lockEntered.complete();
        await releaseLock.future;
      });
      await lockEntered.future;

      await tester.tap(resizeHandle);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(tester.getSize(titleColumn).width, 320);

      await tester.tap(find.text('Second Table'));
      await tester.pump();
      await pumpUntilTableView(secondViewId);
      expect(tester.getSize(titleColumn).width, 200);

      releaseLock.complete();
      await lockFuture;
      final firstAfterRelease = await waitForWidth(seeded.id, 320);
      final secondAfterRelease = (await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: databaseKey,
      )).singleWhere((candidate) => candidate.id == secondViewId);

      expect(firstAfterRelease.settings['unrelated'], 'keep');
      final secondWidths =
          secondAfterRelease.settings[DatabaseViewTableColumnWidthsAdapter
                  .settingsKey]
              as Map;
      expect(secondAfterRelease.settings['second'], 'keep');
      expect((secondWidths['title'] as num).toDouble(), 200);
      expect(tester.getSize(titleColumn).width, 200);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
