import 'app_database.dart';

class BookmarkRepository {
  BookmarkRepository(this._database);

  final AppDatabase _database;

  Stream<List<BookmarkItem>> watchAll() => _database.watchBookmarkItems();

  Stream<List<Tag>> watchTags() => _database.watchAllTags();

  Stream<List<SavedView>> watchSavedViews() => _database.watchSavedViews();

  Future<int> create({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    bool favorite = false,
  }) {
    return _database.addBookmark(
      url: url,
      title: title,
      thumbnail: thumbnail,
      description: description,
      tagNames: tagNames,
      favorite: favorite,
    );
  }

  Future<void> update({
    required int id,
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
  }) {
    return _database.updateBookmarkFields(
      id: id,
      url: url,
      title: title,
      thumbnail: thumbnail,
      description: description,
      tagNames: tagNames,
    );
  }

  Future<void> toggleFavorite(BookmarkItem bookmark) {
    return _database.setFavorite(bookmark.id, !bookmark.favorite);
  }

  Future<int> delete(int id) => _database.deleteBookmark(id);

  Future<void> renameTag(Tag tag, String newName) {
    return _database.renameTag(tag.id, newName);
  }

  Future<void> setTagParent(Tag tag, Tag? parent) {
    return _database.setTagParent(tag.id, parent?.id);
  }

  Future<void> deleteTag(Tag tag) => _database.deleteTag(tag.id);

  Future<int> createSavedView({
    required String name,
    required String layoutType,
    String searchQuery = '',
    bool favoritesOnly = false,
    int? tagId,
  }) {
    return _database.createSavedView(
      name: name,
      layoutType: layoutType,
      searchQuery: searchQuery,
      favoritesOnly: favoritesOnly,
      tagId: tagId,
    );
  }

  Future<void> updateSavedView({
    required int id,
    required String name,
    required String layoutType,
    required String searchQuery,
    required bool favoritesOnly,
    int? tagId,
  }) {
    return _database.updateSavedView(
      id: id,
      name: name,
      layoutType: layoutType,
      searchQuery: searchQuery,
      favoritesOnly: favoritesOnly,
      tagId: tagId,
    );
  }

  Future<int> deleteSavedView(int id) => _database.deleteSavedView(id);
}
