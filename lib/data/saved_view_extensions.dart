import 'app_database.dart';
import 'bookmark_repository.dart';

extension SavedViewDuplication on BookmarkRepository {
  Future<int> duplicateSavedView(
    SavedViewConfig config, {
    required String name,
  }) =>
      createSavedView(
        name: name,
        layoutType: config.view.layoutType,
        searchQuery: config.view.searchQuery,
        favoritesOnly: config.view.favoritesOnly,
        tagIds: config.tags.map((tag) => tag.id),
        tagMatchMode: config.view.tagMatchMode,
        sortField: config.view.sortField,
        sortDirection: config.view.sortDirection,
        visibleProperties: config.view.visibleProperties,
        statusFilter: config.view.statusFilter,
        minRating: config.view.minRating,
        includeDescendants: config.view.includeDescendants,
        personFilterId: config.view.personFilterId,
        photoFilterId: config.view.photoFilterId,
      );
}
