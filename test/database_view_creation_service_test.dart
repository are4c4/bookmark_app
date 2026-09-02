import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_creation_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DatabaseViewStore store;
  late DatabaseViewCreationService service;
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
      DatabasePropertyDefinition(
        key: 'rating',
        label: 'Rating',
        type: DatabasePropertyType.rating,
        icon: Icons.star_outline,
      ),
    ],
    defaultLayout: 'table',
    supportedLayouts: <String>['table', 'gallery'],
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    store = DatabaseViewStore(database);
    service = DatabaseViewCreationService(store);
  });

  tearDown(() => database.close());

  test('duplicate current View copies configuration into a new identity', () async {
    final sourceId = await store.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: '読書中',
      layoutType: 'gallery',
      filters: const <String, dynamic>{'query': 'Serre'},
      sorts: const <dynamic>[
        <String, dynamic>{'field': 'rating', 'direction': 'desc'},
      ],
      visibleProperties: const <String>['title'],
      propertyOrder: const <String>['rating', 'title'],
      settings: const <String, dynamic>{'openMode': 'sidePeek'},
    );
    final source = (await store.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .singleWhere((view) => view.id == sourceId);

    final duplicate = await service.duplicateCurrent(source);

    expect(duplicate.id, isNot(source.id));
    expect(duplicate.name, '読書中 のコピー');
    expect(duplicate.layoutType, source.layoutType);
    expect(duplicate.filters, source.filters);
    expect(duplicate.sorts, source.sorts);
    expect(duplicate.visibleProperties, source.visibleProperties);
    expect(duplicate.propertyOrder, source.propertyOrder);
    expect(duplicate.settings, source.settings);

    await store.updateView(
      duplicate.copyWith(filters: const <String, dynamic>{'query': 'changed'}),
    );
    final reloaded = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    expect(
      reloaded.singleWhere((view) => view.id == source.id).filters,
      const <String, dynamic>{'query': 'Serre'},
    );
  });

  test('blank View starts from Database definition defaults without query state',
      () async {
    final blank = await service.createBlank(
      workspaceId: workspaceId,
      definition: definition,
    );

    expect(blank.name, '新しいビュー');
    expect(blank.layoutType, definition.defaultLayout);
    expect(blank.filters, isEmpty);
    expect(blank.sorts, isEmpty);
    expect(blank.settings, isEmpty);
    expect(blank.visibleProperties, definition.defaultVisibleProperties);
    expect(blank.propertyOrder, definition.defaultPropertyOrder);
  });
}
