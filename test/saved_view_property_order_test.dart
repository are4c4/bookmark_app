import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/saved_view_extensions.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/bookmark_property_order.dart';
import 'package:bookmark_app/views/bookmark_query_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('property order keeps custom order and role positions', () {
    final order = normalizeBookmarkPropertyOrder([
      'status',
      'role:著者',
      'tags',
      'url',
    ]);
    final visibleProperties = <BookmarkStage1Property>{
      BookmarkStage1Property.status,
      BookmarkStage1Property.tags,
      BookmarkStage1Property.url,
    };
    final visibleRoles = <String>{'著者'};

    expect(
      visibleBookmarkPropertyTokens(order, visibleProperties, visibleRoles),
      ['status', 'role:著者', 'tags', 'url'],
    );
    expect(
      orderedVisibleBookmarkProperties(order, visibleProperties),
      [
        BookmarkStage1Property.status,
        BookmarkStage1Property.tags,
        BookmarkStage1Property.url,
      ],
    );
    expect(orderedVisiblePersonRoles(order, visibleRoles), ['著者']);
  });

  test('duplicating saved view preserves filters and property order', () async {
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

    final tagId = await repository.createTag('Flutter');
    final sourceId = await repository.createSavedView(
      name: 'Source',
      layoutType: 'table',
      searchQuery: 'dart',
      favoritesOnly: true,
      tagIds: [tagId],
      tagMatchMode: 'and',
      sortField: 'title',
      sortDirection: 'asc',
      visibleProperties: 'status,tags,url,role:著者',
      statusFilter: 'done',
      minRating: 3,
      includeDescendants: false,
    );
    final source = (await repository.watchSavedViews().first)
        .firstWhere((config) => config.view.id == sourceId);

    final copyId = await repository.duplicateSavedView(
      source,
      name: 'Source のコピー',
    );
    final copy = (await repository.watchSavedViews().first)
        .firstWhere((config) => config.view.id == copyId);

    expect(copy.view.name, 'Source のコピー');
    expect(copy.view.layoutType, 'table');
    expect(copy.view.searchQuery, 'dart');
    expect(copy.view.favoritesOnly, isTrue);
    expect(copy.view.tagMatchMode, 'and');
    expect(copy.view.sortField, 'title');
    expect(copy.view.sortDirection, 'asc');
    expect(copy.view.visibleProperties, 'status,tags,url,role:著者');
    expect(copy.view.statusFilter, 'done');
    expect(copy.view.minRating, 3);
    expect(copy.view.includeDescendants, isFalse);
    expect(copy.tags.map((tag) => tag.name), contains('Flutter'));
  });
}
