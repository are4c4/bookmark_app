import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_open_mode_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_open_presentation_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:bookmark_app/features/object/presentation/object_open_presentation_host.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const host = ObjectOpenPresentationHost();

  testWidgets('side peek delegates to contextual pane without navigation',
      (tester) async {
    var sidePeekCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => host.open(
              context: context,
              mode: ObjectOpenMode.sidePeek,
              onSidePeek: () => sidePeekCount += 1,
              detailBuilder: (_) => const Text('detail-content'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(sidePeekCount, 1);
    expect(find.text('detail-content'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('center peek presents the shared detail builder in a dialog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => host.open(
              context: context,
              mode: ObjectOpenMode.centerPeek,
              onSidePeek: () {},
              detailBuilder: (_) => const Material(
                child: Center(child: Text('detail-content')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('detail-content'), findsOneWidget);
  });

  testWidgets('full page pushes the shared detail builder as a route',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => host.open(
              context: context,
              mode: ObjectOpenMode.fullPage,
              onSidePeek: () {},
              detailBuilder: (_) => const Scaffold(
                body: Center(child: Text('detail-content')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('detail-content'), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });

  testWidgets(
      'openResolved applies View override before ObjectType default and presents it',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectTypeId = await genericStore.createDatabase(
      workspaceId: workspaceId,
      name: 'Note',
    );
    await ObjectTypeDefaultsStore(genericStore).write(
      objectTypeId: objectTypeId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );

    const definition = DatabaseDefinition(
      key: 'custom:notes',
      label: 'Notes',
      icon: Icons.note_outlined,
      properties: <DatabasePropertyDefinition>[],
      defaultLayout: 'list',
      supportedLayouts: <String>['list'],
    );
    final viewStore = DatabaseViewStore(database);
    final viewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'All',
      settings: const <String, dynamic>{'openMode': 'fullPage'},
    );
    final view = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .singleWhere((candidate) => candidate.id == viewId);
    final resolver = ObjectOpenPresentationService(
      viewOpenModes: DatabaseViewOpenModeService(viewStore),
      objectTypeDefaults: ObjectTypeDefaultsStore(genericStore),
    );
    ObjectOpenMode? resolved;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resolved = await host.openResolved(
                context: context,
                resolver: resolver,
                view: view,
                objectTypeId: objectTypeId,
                onSidePeek: () {},
                detailBuilder: (_) => const Scaffold(
                  body: Center(child: Text('resolved-detail')),
                ),
              );
            },
            child: const Text('open-resolved'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-resolved'));
    await tester.pumpAndSettle();

    expect(find.text('resolved-detail'), findsOneWidget);
    expect(find.text('open-resolved'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(resolved, ObjectOpenMode.fullPage);
    expect(find.text('open-resolved'), findsOneWidget);
  });
}
