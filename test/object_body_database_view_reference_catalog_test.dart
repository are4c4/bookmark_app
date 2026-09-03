import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/features/object/presentation/object_body_database_view_reference_catalog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog returns Database entries followed by their persisted Views', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final viewStore = DatabaseViewStore(database);

    final booksId = await genericStore.createDatabase(
      workspaceId: workspaceId,
      name: '読書管理',
      icon: '📚',
    );
    final placesId = await genericStore.createDatabase(
      workspaceId: workspaceId,
      name: '旅行候補',
      icon: '📍',
    );
    final booksDefinition = DatabaseDefinition(
      key: 'custom:$booksId',
      label: '読書管理',
      icon: Icons.book_outlined,
      properties: const [],
    );
    final placesDefinition = DatabaseDefinition(
      key: 'custom:$placesId',
      label: '旅行候補',
      icon: Icons.place_outlined,
      properties: const [],
    );
    final readingViewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: booksDefinition,
      name: '読書中',
    );
    final hokkaidoViewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: placesDefinition,
      name: '北海道',
    );

    final candidates = await ObjectBodyDatabaseViewReferenceCatalog(
      databaseStore: genericStore,
      viewStore: viewStore,
    ).load(workspaceId: workspaceId);

    expect(candidates, hasLength(4));
    expect(candidates[0].databaseId, booksId);
    expect(candidates[0].databaseName, '読書管理');
    expect(candidates[0].databaseIcon, '📚');
    expect(candidates[0].viewId, isNull);
    expect(candidates[1].databaseId, booksId);
    expect(candidates[1].viewId, readingViewId);
    expect(candidates[1].viewName, '読書中');
    expect(candidates[2].databaseId, placesId);
    expect(candidates[2].viewId, isNull);
    expect(candidates[3].databaseId, placesId);
    expect(candidates[3].viewId, hokkaidoViewId);
    expect(candidates[3].viewName, '北海道');
  });
}
