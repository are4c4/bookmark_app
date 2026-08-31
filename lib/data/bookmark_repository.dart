import 'app_database.dart';

class BookmarkRepository {
  BookmarkRepository(this._database);

  final AppDatabase _database;

  Stream<List<BookmarkItem>> watchAll() => _database.watchBookmarkItems();
  Stream<List<Tag>> watchTags() => _database.watchAllTags();
  Stream<List<SavedViewConfig>> watchSavedViews() =>
      _database.watchSavedViewConfigs();

  Future<int> create({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    bool favorite = false,
  }) => _database.addBookmark(
        url: url,
        title: title,
        thumbnail: thumbnail,
        description: description,
        tagNames: tagNames,
        favorite: favorite,
      );

  Future<void> update({
    required int id,
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
  }) => _database.updateBookmarkFields(
        id: id,
        url: url,
        title: title,
        thumbnail: thumbnail,
        description: description,
        tagNames: tagNames,
      );

  Future<void> toggleFavorite(BookmarkItem bookmark) =>
      _database.setFavorite(bookmark.id, !bookmark.favorite);

  Future<int> delete(int id) => _database.deleteBookmark(id);

  Future<void> renameTag(Tag tag, String newName) =>
      _database.renameTag(tag.id, newName);

  Future<void> setTagParent(Tag tag, Tag? parent) =>
      _database.setTagParent(tag.id, parent?.id);

  Future<void> deleteTag(Tag tag) => _database.deleteTag(tag.id);

  Future<int> createSavedView({
    required String name,
    required String layoutType,
    String searchQuery = '',
    bool favoritesOnly = false,
    Iterable<int> tagIds = const [],
    String tagMatchMode = 'or',
    String sortField = 'createdAt',
    String sortDirection = 'desc',
  }) => _database.createSavedView(
        name: name,
        layoutType: layoutType,
        searchQuery: searchQuery,
        favoritesOnly: favoritesOnly,
        tagIds: tagIds,
        tagMatchMode: tagMatchMode,
        sortField: sortField,
        sortDirection: sortDirection,
      );

  Future<void> updateSavedView({
    required int id,
    required String name,
    required String layoutType,
    required String searchQuery,
    required bool favoritesOnly,
    required Iterable<int> tagIds,
    required String tagMatchMode,
    required String sortField,
    required String sortDirection,
  }) => _database.updateSavedView(
        id: id,
        name: name,
        layoutType: layoutType,
        searchQuery: searchQuery,
        favoritesOnly: favoritesOnly,
        tagIds: tagIds,
        tagMatchMode: tagMatchMode,
        sortField: sortField,
        sortDirection: sortDirection,
      );

  Future<int> deleteSavedView(int id) => _database.deleteSavedView(id);
}
