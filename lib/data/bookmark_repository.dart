import 'app_database.dart';

class BookmarkRepository {
  BookmarkRepository(this._database);

  final AppDatabase _database;

  Stream<List<BookmarkItem>> watchAll() => _database.watchBookmarkItems();
  Stream<List<Tag>> watchTags() => _database.watchAllTags();
  Stream<List<Person>> watchPeople() => _database.watchAllPeople();
  Stream<List<PhotoRecord>> watchPhotos() => _database.watchAllPhotos();
  Stream<List<CollectionRecord>> watchCollections() => _database.watchAllCollections();
  Stream<List<BookmarkRelation>> watchRelationsForBookmark(int bookmarkId) =>
      _database.watchRelationsForBookmark(bookmarkId);
  Stream<List<SavedViewConfig>> watchSavedViews() => _database.watchSavedViewConfigs();

  Stream<List<BookmarkItem>> watchBookmarksForPerson(Person person) => watchAll().map(
        (items) => items.where((item) => item.people.any((candidate) => candidate.id == person.id)).toList(),
      );

  Stream<List<BookmarkItem>> watchBookmarksForPhoto(PhotoRecord photo) => watchAll().map(
        (items) => items.where((item) => item.photos.any((candidate) => candidate.id == photo.id)).toList(),
      );

  String _normalizeUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return trimmed.toLowerCase().replaceAll(RegExp(r'/$'), '');
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final path = uri.path == '/' ? '' : uri.path.replaceAll(RegExp(r'/$'), '');
    return '$host$path${uri.hasQuery ? '?${uri.query}' : ''}';
  }

  Future<BookmarkItem?> findDuplicateUrl(String url) async {
    final normalized = _normalizeUrl(url);
    final items = await watchAll().first;
    for (final item in items) {
      if (_normalizeUrl(item.url) == normalized) return item;
    }
    return null;
  }

  Future<int> create({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    Iterable<String> personNames = const [],
    bool favorite = false,
    String status = 'unread',
    int rating = 0,
  }) => _database.addBookmark(
        url: url,
        title: title,
        thumbnail: thumbnail,
        description: description,
        tagNames: tagNames,
        personNames: personNames,
        favorite: favorite,
        status: status,
        rating: rating,
      );

  Future<void> update({
    required int id,
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    Iterable<String>? personNames,
    String? status,
    int? rating,
  }) => _database.updateBookmarkFields(
        id: id,
        url: url,
        title: title,
        thumbnail: thumbnail,
        description: description,
        tagNames: tagNames,
        personNames: personNames,
        status: status,
        rating: rating,
      );

  Future<void> setBookmarkTagsFromDatabase(BookmarkItem bookmark, Iterable<Tag> selectedTags) =>
      _database.setBookmarkTags(bookmark.id, selectedTags.map((tag) => tag.name));

  Future<void> setBookmarkPeopleFromDatabase(BookmarkItem bookmark, Iterable<Person> selectedPeople) =>
      _database.setBookmarkPeople(bookmark.id, selectedPeople.map((person) => person.name));

  Future<void> setBookmarkCollections(BookmarkItem bookmark, Iterable<CollectionRecord> selected) =>
      _database.setBookmarkCollections(bookmark.id, selected.map((collection) => collection.name));

  Future<void> toggleFavorite(BookmarkItem bookmark) => _database.setFavorite(bookmark.id, !bookmark.favorite);
  Future<void> setStatus(BookmarkItem bookmark, String status) => _database.setStatus(bookmark.id, status);
  Future<void> setRating(BookmarkItem bookmark, int rating) => _database.setRating(bookmark.id, rating);
  Future<void> recordOpen(BookmarkItem bookmark) => _database.recordBookmarkOpen(bookmark.id);
  Future<int> delete(int id) => _database.deleteBookmark(id);

  Future<void> batchAddTags(Iterable<int> ids, Iterable<String> names) => _database.addTagsToBookmarks(ids, names);
  Future<void> batchRemoveTags(Iterable<int> ids, Iterable<String> names) => _database.removeTagsFromBookmarks(ids, names);
  Future<void> batchAddPeople(Iterable<int> ids, Iterable<String> names) => _database.addPeopleToBookmarks(ids, names);
  Future<void> batchRemovePeople(Iterable<int> ids, Iterable<String> names) => _database.removePeopleFromBookmarks(ids, names);
  Future<void> batchSetStatus(Iterable<int> ids, String status) => _database.batchSetStatus(ids, status);
  Future<void> batchSetRating(Iterable<int> ids, int rating) => _database.batchSetRating(ids, rating);
  Future<void> batchSetFavorite(Iterable<int> ids, bool favorite) => _database.batchSetFavorite(ids, favorite);
  Future<void> batchDelete(Iterable<int> ids) async {
    for (final id in ids.toSet()) {
      await _database.deleteBookmark(id);
    }
  }

  Future<int> addPhoto({
    required String path,
    String? title,
    String? note,
    Iterable<String> tagNames = const [],
  }) => _database.addPhoto(path: path, title: title, note: note, tagNames: tagNames);

  Future<void> updatePhoto(PhotoRecord photo, {String? title, String? note, Iterable<String>? tagNames}) =>
      _database.updatePhoto(photo.id, title: title, note: note, tagNames: tagNames);

  Future<void> deletePhoto(PhotoRecord photo) => _database.deletePhoto(photo.id);

  Future<void> attachPhoto(BookmarkItem bookmark, PhotoRecord photo, {bool asCover = false}) =>
      _database.attachPhotoToBookmark(bookmark.id, photo.id, asCover: asCover);

  Future<void> attachPhotos(BookmarkItem bookmark, Iterable<PhotoRecord> photos, {PhotoRecord? coverPhoto}) =>
      _database.attachPhotosToBookmark(
        bookmark.id,
        photos.map((photo) => photo.id),
        coverPhotoId: coverPhoto?.id,
      );

  Future<void> attachPhotosByBookmarkId(int bookmarkId, Iterable<PhotoRecord> photos, {PhotoRecord? coverPhoto}) =>
      _database.attachPhotosToBookmark(
        bookmarkId,
        photos.map((photo) => photo.id),
        coverPhotoId: coverPhoto?.id,
      );

  Future<void> detachPhoto(BookmarkItem bookmark, PhotoRecord photo) =>
      _database.detachPhotoFromBookmark(bookmark.id, photo.id);
  Future<void> setCoverPhoto(BookmarkItem bookmark, PhotoRecord photo) =>
      _database.setCoverPhoto(bookmark.id, photo.id);
  Future<void> clearCoverPhoto(BookmarkItem bookmark) => _database.clearCoverPhoto(bookmark.id);

  Future<int> createPerson(String name, {String? note}) => _database.createPerson(name, note: note);
  Future<void> updatePerson(Person person, String name, String? note, {PhotoRecord? profilePhoto, bool updateProfilePhoto = false}) =>
      _database.updatePerson(
        person.id,
        name,
        note,
        profilePhotoId: profilePhoto?.id,
        updateProfilePhoto: updateProfilePhoto,
      );
  Future<void> deletePerson(Person person) => _database.deletePerson(person.id);

  Future<int> createCollection(String name, {String? note}) => _database.createCollection(name, note: note);
  Future<void> deleteCollection(CollectionRecord collection) => _database.deleteCollection(collection.id);

  Future<void> addRelation(BookmarkItem source, BookmarkItem target, String type) =>
      _database.addBookmarkRelation(source.id, target.id, type);
  Future<void> removeRelation(int sourceId, int targetId, String type) =>
      _database.removeBookmarkRelation(sourceId, targetId, type);

  Future<int> createTag(String name, {Tag? parent}) => _database.createTag(name, parentTagId: parent?.id);
  Future<void> renameTag(Tag tag, String newName) => _database.renameTag(tag.id, newName);
  Future<void> setTagParent(Tag tag, Tag? parent) => _database.setTagParent(tag.id, parent?.id);
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
    String visibleProperties = 'image,url,tags,favorite',
    String statusFilter = '',
    int minRating = 0,
  }) => _database.createSavedView(
        name: name,
        layoutType: layoutType,
        searchQuery: searchQuery,
        favoritesOnly: favoritesOnly,
        tagIds: tagIds,
        tagMatchMode: tagMatchMode,
        sortField: sortField,
        sortDirection: sortDirection,
        visibleProperties: visibleProperties,
        statusFilter: statusFilter,
        minRating: minRating,
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
    required String visibleProperties,
    required String statusFilter,
    required int minRating,
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
        visibleProperties: visibleProperties,
        statusFilter: statusFilter,
        minRating: minRating,
      );

  Future<int> deleteSavedView(int id) => _database.deleteSavedView(id);
}
