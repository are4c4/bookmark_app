import 'app_database.dart';

class BookmarkRepository {
  BookmarkRepository(this._database);

  final AppDatabase _database;

  Stream<List<BookmarkItem>> watchAll() => _database.watchBookmarkItems();
  Stream<List<Tag>> watchTags() => _database.watchAllTags();
  Stream<List<Person>> watchPeople() => _database.watchAllPeople();
  Stream<List<PhotoRecord>> watchPhotos() => _database.watchAllPhotos();
  Stream<List<SavedViewConfig>> watchSavedViews() =>
      _database.watchSavedViewConfigs();

  Stream<List<BookmarkItem>> watchBookmarksForPerson(Person person) =>
      watchAll().map(
        (items) => items
            .where((item) => item.people.any((candidate) => candidate.id == person.id))
            .toList(),
      );

  Stream<List<BookmarkItem>> watchBookmarksForPhoto(PhotoRecord photo) =>
      watchAll().map(
        (items) => items
            .where((item) => item.photos.any((candidate) => candidate.id == photo.id))
            .toList(),
      );

  Future<int> create({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    Iterable<String> personNames = const [],
    bool favorite = false,
  }) => _database.addBookmark(
        url: url,
        title: title,
        thumbnail: thumbnail,
        description: description,
        tagNames: tagNames,
        personNames: personNames,
        favorite: favorite,
      );

  Future<void> update({
    required int id,
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    Iterable<String>? personNames,
  }) => _database.updateBookmarkFields(
        id: id,
        url: url,
        title: title,
        thumbnail: thumbnail,
        description: description,
        tagNames: tagNames,
        personNames: personNames,
      );

  Future<void> toggleFavorite(BookmarkItem bookmark) =>
      _database.setFavorite(bookmark.id, !bookmark.favorite);
  Future<int> delete(int id) => _database.deleteBookmark(id);

  Future<int> addPhoto({
    required String path,
    String? title,
    String? note,
    Iterable<String> tagNames = const [],
  }) => _database.addPhoto(
        path: path,
        title: title,
        note: note,
        tagNames: tagNames,
      );

  Future<void> updatePhoto(
    PhotoRecord photo, {
    String? title,
    String? note,
    Iterable<String>? tagNames,
  }) => _database.updatePhoto(
        photo.id,
        title: title,
        note: note,
        tagNames: tagNames,
      );

  Future<void> deletePhoto(PhotoRecord photo) => _database.deletePhoto(photo.id);

  Future<void> attachPhoto(
    BookmarkItem bookmark,
    PhotoRecord photo, {
    bool asCover = false,
  }) => _database.attachPhotoToBookmark(bookmark.id, photo.id, asCover: asCover);

  Future<void> attachPhotos(
    BookmarkItem bookmark,
    Iterable<PhotoRecord> photos, {
    PhotoRecord? coverPhoto,
  }) => _database.attachPhotosToBookmark(
        bookmark.id,
        photos.map((photo) => photo.id),
        coverPhotoId: coverPhoto?.id,
      );

  Future<void> attachPhotosByBookmarkId(
    int bookmarkId,
    Iterable<PhotoRecord> photos, {
    PhotoRecord? coverPhoto,
  }) => _database.attachPhotosToBookmark(
        bookmarkId,
        photos.map((photo) => photo.id),
        coverPhotoId: coverPhoto?.id,
      );

  Future<void> detachPhoto(BookmarkItem bookmark, PhotoRecord photo) =>
      _database.detachPhotoFromBookmark(bookmark.id, photo.id);

  Future<void> setCoverPhoto(BookmarkItem bookmark, PhotoRecord photo) =>
      _database.setCoverPhoto(bookmark.id, photo.id);

  Future<void> clearCoverPhoto(BookmarkItem bookmark) =>
      _database.clearCoverPhoto(bookmark.id);

  Future<int> createPerson(String name, {String? note}) =>
      _database.createPerson(name, note: note);
  Future<void> updatePerson(Person person, String name, String? note) =>
      _database.updatePerson(person.id, name, note);
  Future<void> deletePerson(Person person) => _database.deletePerson(person.id);

  Future<int> createTag(String name, {Tag? parent}) =>
      _database.createTag(name, parentTagId: parent?.id);
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
