import 'package:drift/drift.dart';

import 'app_database.dart';

/// Owns Saved View persistence mutations while reads remain in
/// [SavedViewReadStore]. Workspace assignment stays with [WorkspaceStore].
class SavedViewWriteStore {
  const SavedViewWriteStore(this.database);

  final AppDatabase database;

  Future<void> _setTags(int viewId, Iterable<int> tagIds) async {
    await (database.delete(database.savedViewTags)
          ..where((row) => row.savedViewId.equals(viewId)))
        .go();
    for (final tagId in tagIds.toSet()) {
      await database.into(database.savedViewTags).insert(
            SavedViewTagsCompanion.insert(
              savedViewId: viewId,
              tagId: tagId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<int> create({
    required String name,
    required String layoutType,
    String searchQuery = '',
    bool favoritesOnly = false,
    Iterable<int> tagIds = const [],
    String tagMatchMode = 'or',
    String sortField = 'createdAt',
    String sortDirection = 'desc',
    String visibleProperties = 'image,url,tags,favorite',
    String statusFilter = '',
    int minRating = 0,
    bool includeDescendants = true,
    int? personFilterId,
    int? photoFilterId,
  }) =>
      database.transaction(() async {
        final id = await database.into(database.savedViews).insert(
              SavedViewsCompanion.insert(
                name: name,
                layoutType: Value(layoutType),
                searchQuery: Value(searchQuery),
                favoritesOnly: Value(favoritesOnly),
                tagMatchMode: Value(tagMatchMode),
                sortField: Value(sortField),
                sortDirection: Value(sortDirection),
                visibleProperties: Value(visibleProperties),
                statusFilter: Value(statusFilter),
                minRating: Value(minRating.clamp(0, 5)),
                includeDescendants: Value(includeDescendants),
                personFilterId: Value(personFilterId),
                photoFilterId: Value(photoFilterId),
              ),
            );
        await _setTags(id, tagIds);
        return id;
      });

  Future<void> update({
    required int id,
    required String name,
    required String layoutType,
    required String searchQuery,
    required bool favoritesOnly,
    required Iterable<int> tagIds,
    required String tagMatchMode,
    required String sortField,
    required String sortDirection,
    required String visibleProperties,
    required String statusFilter,
    required int minRating,
    required bool includeDescendants,
    int? personFilterId,
    int? photoFilterId,
  }) =>
      database.transaction(() async {
        await (database.update(database.savedViews)
              ..where((view) => view.id.equals(id)))
            .write(
          SavedViewsCompanion(
            name: Value(name),
            layoutType: Value(layoutType),
            searchQuery: Value(searchQuery),
            favoritesOnly: Value(favoritesOnly),
            tagMatchMode: Value(tagMatchMode),
            sortField: Value(sortField),
            sortDirection: Value(sortDirection),
            visibleProperties: Value(visibleProperties),
            statusFilter: Value(statusFilter),
            minRating: Value(minRating.clamp(0, 5)),
            includeDescendants: Value(includeDescendants),
            personFilterId: Value(personFilterId),
            photoFilterId: Value(photoFilterId),
          ),
        );
        await _setTags(id, tagIds);
      });

  Future<int> delete(int id) =>
      (database.delete(database.savedViews)..where((view) => view.id.equals(id)))
          .go();
}
