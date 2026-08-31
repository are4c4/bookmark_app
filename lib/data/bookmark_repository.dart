import 'app_database.dart';

class BookmarkRepository {
  BookmarkRepository(this._database);

  final AppDatabase _database;

  Stream<List<Bookmark>> watchAll() => _database.watchAllBookmarks();

  Stream<List<Bookmark>> watchFavorites() => _database.watchFavorites();

  Future<Bookmark?> findById(int id) => _database.getBookmarkById(id);

  Future<int> create({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    bool favorite = false,
  }) {
    return _database.addBookmark(
      url: url,
      title: title,
      thumbnail: thumbnail,
      description: description,
      favorite: favorite,
    );
  }

  Future<void> toggleFavorite(Bookmark bookmark) {
    return _database.setFavorite(bookmark.id, !bookmark.favorite);
  }

  Future<void> setThumbnail(int id, String? pathOrUrl) {
    return _database.updateThumbnail(id, pathOrUrl);
  }

  Future<int> delete(int id) => _database.deleteBookmark(id);
}
