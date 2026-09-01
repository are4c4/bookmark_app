import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database views are scoped by workspace and database', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final firstWorkspace = await workspaceStore.initialize();
    final secondWorkspace = await workspaceStore.createWorkspace('Second');
    final store = DatabaseViewStore(database);

    await store.createView(
      workspaceId: firstWorkspace,
      definition: BuiltInDatabases.bookmarks,
      name: '音楽',
      filters: const {'query': 'music'},
    );
    await store.createView(
      workspaceId: firstWorkspace,
      definition: BuiltInDatabases.people,
      name: 'ReHacQ',
    );
    await store.createView(
      workspaceId: secondWorkspace,
      definition: BuiltInDatabases.bookmarks,
      name: '仕事',
    );

    final bookmarkViews = await store.listViews(
      workspaceId: firstWorkspace,
      databaseKey: 'bookmarks',
    );
    final peopleViews = await store.listViews(
      workspaceId: firstWorkspace,
      databaseKey: 'people',
    );
    final otherWorkspaceViews = await store.listViews(
      workspaceId: secondWorkspace,
      databaseKey: 'bookmarks',
    );

    expect(bookmarkViews.map((view) => view.name), ['音楽']);
    expect(peopleViews.map((view) => view.name), ['ReHacQ']);
    expect(otherWorkspaceViews.map((view) => view.name), ['仕事']);
  });

  test('default, duplicate and reorder preserve generic view settings', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final store = DatabaseViewStore(database);

    final defaultView = await store.ensureDefaultView(
      workspaceId: workspaceId,
      definition: BuiltInDatabases.photos,
    );
    expect(defaultView.name, 'すべて');
    expect(defaultView.layoutType, 'gallery');

    final configuredId = await store.createView(
      workspaceId: workspaceId,
      definition: BuiltInDatabases.photos,
      name: '人物写真',
      layoutType: 'list',
      filters: const {'query': 'portrait'},
      sorts: const [
        {'field': 'createdAt', 'direction': 'desc'},
      ],
      visibleProperties: const ['image', 'title', 'tags'],
      propertyOrder: const ['title', 'image', 'tags'],
      settings: const {'cardSize': 'small'},
    );
    final configured = (await store.listViews(
      workspaceId: workspaceId,
      databaseKey: 'photos',
    ))
        .firstWhere((view) => view.id == configuredId);

    final duplicateId = await store.duplicateView(configured);
    var views = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: 'photos',
    );
    final duplicate = views.firstWhere((view) => view.id == duplicateId);
    expect(duplicate.layoutType, 'list');
    expect(duplicate.filters['query'], 'portrait');
    expect(duplicate.propertyOrder, ['title', 'image', 'tags']);
    expect(duplicate.settings['cardSize'], 'small');

    await store.reorderViews([duplicate, configured, defaultView]);
    views = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: 'photos',
    );
    expect(views.map((view) => view.id), [duplicate.id, configured.id, defaultView.id]);
  });

  test('collections share the generic database view model', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final store = DatabaseViewStore(database);

    final view = await store.ensureDefaultView(
      workspaceId: workspaceId,
      definition: BuiltInDatabases.collections,
    );

    expect(view.databaseKey, 'collections');
    expect(view.name, 'すべて');
    expect(view.layoutType, 'list');
    expect(BuiltInDatabases.collections.supportedLayouts, ['list']);
  });

  test('all core databases are registered through shared definitions', () {
    expect(
      BuiltInDatabases.all.map((definition) => definition.key).toSet(),
      {'bookmarks', 'people', 'photos', 'collections'},
    );
    for (final definition in BuiltInDatabases.all) {
      expect(definition.properties, isNotEmpty);
      expect(definition.supportedLayouts, contains(definition.defaultLayout));
      expect(BuiltInDatabases.byKey(definition.key), same(definition));
    }
  });
}
