import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/services/collection_management_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rename preserves Collection identity and unrelated note', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    await workspaceStore.initialize();
    final service = CollectionManagementService.fromWorkspaceStore(
      workspaceStore,
    );

    final id = await database.createCollection('Before', note: 'keep me');
    final before = (await database.watchAllCollections().first).singleWhere(
      (collection) => collection.id == id,
    );

    await service.renameCollection(before, '  After  ');

    final after = (await database.watchAllCollections().first).singleWhere(
      (collection) => collection.id == id,
    );
    expect(after.id, id);
    expect(after.name, 'After');
    expect(after.note, 'keep me');

    await service.renameCollection(after, '   ');
    final unchanged = (await database.watchAllCollections().first).singleWhere(
      (collection) => collection.id == id,
    );
    expect(unchanged.name, 'After');
  });

  test('note save trims text and maps blank text to null', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    await workspaceStore.initialize();
    final service = CollectionManagementService.fromWorkspaceStore(
      workspaceStore,
    );

    final id = await database.createCollection('Research');
    var collection = (await database.watchAllCollections().first).singleWhere(
      (item) => item.id == id,
    );

    await service.saveCollectionNote(collection, '  useful note  ');
    collection = (await database.watchAllCollections().first).singleWhere(
      (item) => item.id == id,
    );
    expect(collection.note, 'useful note');

    await service.saveCollectionNote(collection, '   ');
    collection = (await database.watchAllCollections().first).singleWhere(
      (item) => item.id == id,
    );
    expect(collection.note, isNull);
  });

  test('view store remains scoped through the workspace boundary', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final service = CollectionManagementService.fromWorkspaceStore(
      workspaceStore,
    );

    final views = await service.databaseViewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: BuiltInDatabases.collections.key,
    );
    expect(views, isEmpty);
  });
}
