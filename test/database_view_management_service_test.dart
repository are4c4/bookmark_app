import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_management_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DatabaseViewStore store;
  late DatabaseViewManagementService service;
  late int workspaceId;

  const definition = DatabaseDefinition(
    key: 'custom:books',
    label: 'Books',
    icon: Icons.menu_book_outlined,
    properties: <DatabasePropertyDefinition>[
      DatabasePropertyDefinition(
        key: 'title',
        label: 'Title',
        type: DatabasePropertyType.text,
        icon: Icons.title,
      ),
    ],
    defaultLayout: 'table',
    supportedLayouts: <String>['table', 'gallery'],
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    store = DatabaseViewStore(database);
    service = DatabaseViewManagementService(store);
  });

  tearDown(() => database.close());

  Future<DatabaseViewConfig> create(String name) async {
    final id = await store.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: name,
    );
    return (await store.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .singleWhere((view) => view.id == id);
  }

  test('rename normalizes the name and returns canonical persisted state',
      () async {
    final view = await create('Before');

    final renamed = await service.rename(view, '  After  ');

    expect(renamed.name, 'After');
    expect(renamed.id, view.id);
  });

  test('reorder requires the complete Database View scope exactly once',
      () async {
    final a = await create('A');
    final b = await create('B');
    final c = await create('C');

    final reordered = await service.reorder(
      workspaceId: workspaceId,
      databaseKey: definition.key,
      orderedViewIds: <int>[c.id, a.id, b.id],
    );

    expect(reordered.map((view) => view.id), <int>[c.id, a.id, b.id]);
    expect(
      () => service.reorder(
        workspaceId: workspaceId,
        databaseKey: definition.key,
        orderedViewIds: <int>[a.id, b.id],
      ),
      throwsArgumentError,
    );
  });

  test('delete keeps at least one View and rejects a stale cross-scope payload',
      () async {
    final first = await create('A');
    final second = await create('B');

    final remaining = await service.delete(second);
    expect(remaining.map((view) => view.id), <int>[first.id]);
    await expectLater(service.delete(first), throwsStateError);

    final forged = DatabaseViewConfig(
      id: first.id,
      workspaceId: first.workspaceId,
      databaseKey: 'custom:other',
      name: first.name,
      layoutType: first.layoutType,
      filters: first.filters,
      sorts: first.sorts,
      visibleProperties: first.visibleProperties,
      propertyOrder: first.propertyOrder,
      settings: first.settings,
      sortOrder: first.sortOrder,
    );
    await expectLater(service.rename(forged, 'Nope'), throwsArgumentError);
  });
}
