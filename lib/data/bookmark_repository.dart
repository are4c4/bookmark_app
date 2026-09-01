import 'package:rxdart/rxdart.dart';

import '../services/attachment_storage_service.dart';
import '../services/auto_organize_service.dart';
import '../services/photo_storage_service.dart';

import '../domain/bookmark_state.dart';
import 'app_database.dart';
import 'bookmark_attachment_store.dart';
import 'bookmark_lifecycle_store.dart';
import 'person_roles.dart';
import 'workspace_store.dart';

class BookmarkRepository {
  BookmarkRepository(
    this._database, {
    required this.workspaceStore,
    required this.lifecycleStore,
    required this.workspaceId,
    this.profileDirectoryPath,
    AutoOrganizeService? autoOrganizeService,
  }) : autoOrganize =
            autoOrganizeService ?? AutoOrganizeService(_database);

  final AppDatabase _database;
  final WorkspaceStore workspaceStore;
  final BookmarkLifecycleStore lifecycleStore;
  final int workspaceId;
  final String? profileDirectoryPath;
  final AutoOrganizeService autoOrganize;

  String? get photoDirectoryPath =>
      profileDirectoryPath == null ? null : '$profileDirectoryPath/photos';

  Future<List<WorkspaceInfo>> listWorkspaces() => workspaceStore.listWorkspaces();
  Future<int> createWorkspace(String name, {String icon = '📁', int colorValue = 4288585374}) =>
      workspaceStore.createWorkspace(name, icon: icon, colorValue: colorValue);
  Future<void> updateWorkspace(WorkspaceInfo workspace, {String? name, String? icon, int? colorValue}) =>
      workspaceStore.updateWorkspace(workspace.id, name: name, icon: icon, colorValue: colorValue);
  Future<void> renameWorkspace(WorkspaceInfo workspace, String name) =>
      workspaceStore.renameWorkspace(workspace.id, name);
  Future<void> reorderWorkspaces(List<int> orderedIds) => workspaceStore.reorderWorkspaces(orderedIds);
  Future<void> deleteWorkspace(WorkspaceInfo workspace) => workspaceStore.deleteWorkspace(workspace.id);
  Future<void> setActiveWorkspace(WorkspaceInfo workspace) => workspaceStore.setActiveWorkspace(workspace.id);
  Future<void> moveBookmarksToWorkspace(Iterable<int> ids, WorkspaceInfo workspace) =>
      workspaceStore.moveBookmarks(ids, workspace.id);

  Stream<List<BookmarkItem>> _watchWorkspaceItems({
    required bool Function(BookmarkItem item) include,
  }) =>
      Rx.combineLatest2<List<BookmarkItem>, Set<int>, List<BookmarkItem>>(
        _database.watchBookmarkItems(),
        workspaceStore.watchBookmarkIds(workspaceId),
        (items, workspaceIds) => items
            .where((item) => workspaceIds.contains(item.id) && include(item))
            .toList(),
      );

  Stream<List<BookmarkItem>> watchAll() => _watchWorkspaceItems(
        include: (item) =>
            item.storageState != BookmarkStorageState.trashed.storageValue,
      );

  Stream<List<BookmarkItem>> watchInbox() => _watchWorkspaceItems(
        include: (item) =>
            item.storageState == BookmarkStorageState.inbox.storageValue,
      );

  Stream<List<BookmarkItem>> watchArchive() => _watchWorkspaceItems(
        include: (item) =>
            item.storageState == BookmarkStorageState.archived.storageValue,
      );

  Stream<List<BookmarkItem>> watchTrash() => _watchWorkspaceItems(
        include: (item) =>
            item.storageState == BookmarkStorageState.trashed.storageValue,
      );

  Stream<List<Tag>> watchTags() => _database.watchAllTags();
  Stream<List<Person>> watchPeople() => _database.watchAllPeople();
  Stream<List<PhotoRecord>> watchPhotos() => _database.watchAllPhotos();
  Stream<List<CollectionRecord>> watchCollections() => _database.watchAllCollections();
  Stream<List<BookmarkRelation>> watchRelationsForBookmark(int bookmarkId) =>
      _database.watchRelationsForBookmark(bookmarkId);

  Stream<List<SavedViewConfig>> watchSavedViews() =>
      Rx.combineLatest2<List<SavedViewConfig>, Set<int>, List<SavedViewConfig>>(
        _database.watchSavedViewConfigs(),
        workspaceStore.watchSavedViewIds(workspaceId),
        (views, ids) => views.where((config) => ids.contains(config.view.id)).toList(),
      );

  Stream<List<PersonRoleAssignment>> watchPersonRoles(BookmarkItem bookmark) =>
      _database.watchPersonRoleAssignments(bookmark.id);
  Stream<List<PersonRoleAssignment>> watchRolesForPerson(Person person) =>
      _database.watchRoleAssignmentsForPerson(person.id);

  Stream<List<BookmarkItem>> watchBookmarksForPerson(Person person) => watchAll().map(
        (items) => items.where((item) => item.people.any((candidate) => candidate.id == person.id)).toList(),
      );
  Stream<List<BookmarkItem>> watchBookmarksForPhoto(PhotoRecord photo) => watchAll().map(
        (items) => items.where((item) => item.photos.any((candidate) => candidate.id == photo.id)).toList(),
      );
  Stream<List<BookmarkItem>> watchBookmarksForCollection(CollectionRecord collection) => watchAll().map(
        (items) => items.where((item) => item.collections.any((candidate) => candidate.id == collection.id)).toList(),
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

  Future<List<Person>> _resolvePeople(Iterable<String> names) async {
    final normalized = <String, String>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.isNotEmpty) normalized[name.toLowerCase()] = name;
    }
    for (final name in normalized.values) {
      await _database.createPerson(name);
    }
    final all = await _database.watchAllPeople().first;
    return all.where((person) => normalized.containsKey(person.name.toLowerCase())).toList();
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
    bool inbox = false,
  }) async {
    final id = await _database.addBookmark(
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
    await workspaceStore.assignBookmark(id, workspaceId);
    await lifecycleStore.ensureBookmark(id, inbox: inbox);
    await autoOrganize.applyToBookmark(
      bookmarkId: id,
      url: url,
      title: title,
      description: description,
    );
    return id;
  }

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
  }) async {
    await _database.updateBookmarkFields(
      id: id,
      url: url,
      title: title,
      thumbnail: thumbnail,
      description: description,
      tagNames: tagNames,
      personNames: null,
      status: status,
      rating: rating,
    );
    if (personNames != null) {
      final people = await _resolvePeople(personNames);
      await _database.setPeopleForRole(id, '出演者', people);
    }
    await autoOrganize.applyToBookmark(
      bookmarkId: id,
      url: url,
      title: title,
      description: description,
    );
  }

  Future<List<AutoOrganizeRule>> listAutoOrganizeRules() =>
      autoOrganize.listRules();

  Future<int> createAutoOrganizeRule({
    required String name,
    required AutoOrganizeMatchField matchField,
    required String keyword,
    String tagName = '',
    String genre = '',
  }) =>
      autoOrganize.createRule(
        name: name,
        matchField: matchField,
        keyword: keyword,
        tagName: tagName,
        genre: genre,
      );

  Future<void> setAutoOrganizeRuleEnabled(int id, bool enabled) =>
      autoOrganize.setEnabled(id, enabled);

  Future<void> deleteAutoOrganizeRule(int id) =>
      autoOrganize.deleteRule(id);

  Future<AutoOrganizeResult> applyAutoOrganizeToAll() async =>
      autoOrganize.applyToAll(await watchAll().first);

  Future<void> setBookmarkTagsFromDatabase(BookmarkItem bookmark, Iterable<Tag> selectedTags) =>
      _database.setBookmarkTags(bookmark.id, selectedTags.map((tag) => tag.name));
  Future<void> setBookmarkPeopleFromDatabase(BookmarkItem bookmark, Iterable<Person> selectedPeople) =>
      _database.setPeopleForRole(bookmark.id, '出演者', selectedPeople);
  Future<void> setPeopleForRole(BookmarkItem bookmark, String role, Iterable<Person> selectedPeople) =>
      _database.setPeopleForRole(bookmark.id, role, selectedPeople);
  Future<void> removePersonFromBookmark(BookmarkItem bookmark, Person person, {String? role}) =>
      _database.removePersonRole(bookmark.id, person, role: role);
  Future<void> setBookmarkCollections(BookmarkItem bookmark, Iterable<CollectionRecord> selected) =>
      _database.setBookmarkCollections(bookmark.id, selected.map((collection) => collection.name));

  Future<void> toggleFavorite(BookmarkItem bookmark) => _database.setFavorite(bookmark.id, !bookmark.favorite);
  Future<void> setStatus(BookmarkItem bookmark, String status) => _database.setStatus(bookmark.id, status);
  Future<void> setRating(BookmarkItem bookmark, int rating) => _database.setRating(bookmark.id, rating);
  Future<void> recordOpen(BookmarkItem bookmark) => _database.recordBookmarkOpen(bookmark.id);
  Future<void> setInbox(BookmarkItem bookmark, bool value) => lifecycleStore.setInbox(bookmark.id, value);
  Future<void> archive(BookmarkItem bookmark) =>
      lifecycleStore.setArchived(bookmark.id, true);
  Future<void> unarchive(BookmarkItem bookmark) =>
      lifecycleStore.setArchived(bookmark.id, false);
  Future<void> moveToTrash(BookmarkItem bookmark) => lifecycleStore.moveToTrash(bookmark.id);
  Future<void> restoreFromTrash(BookmarkItem bookmark) => lifecycleStore.restore(bookmark.id);
  Future<void> permanentDelete(BookmarkItem bookmark) async {
    final attachmentStore = BookmarkAttachmentStore(_database);
    final attachments = await attachmentStore.listForBookmark(bookmark.id);
    const attachmentStorage = AttachmentStorageService();
    for (final attachment in attachments) {
      await attachmentStorage.deleteAttachment(attachment, attachmentStore);
    }
    await lifecycleStore.remove(bookmark.id);
    await _database.deleteBookmark(bookmark.id);
  }
  Future<void> delete(int id) => lifecycleStore.moveToTrash(id);

  Future<void> batchAddTags(Iterable<int> ids, Iterable<String> names) => _database.addTagsToBookmarks(ids, names);
  Future<void> batchRemoveTags(Iterable<int> ids, Iterable<String> names) => _database.removeTagsFromBookmarks(ids, names);

  Future<void> batchAddPeople(Iterable<int> ids, Iterable<String> names) async {
    final adding = await _resolvePeople(names);
    for (final id in ids.toSet()) {
      final assignments = await _database.watchPersonRoleAssignments(id).first;
      final current = assignments
          .where((assignment) => assignment.role == '出演者')
          .map((assignment) => assignment.person)
          .toList();
      final byId = <int, Person>{for (final person in [...current, ...adding]) person.id: person};
      await _database.setPeopleForRole(id, '出演者', byId.values);
    }
  }

  Future<void> batchRemovePeople(Iterable<int> ids, Iterable<String> names) async {
    final removing = names.map((name) => name.trim().toLowerCase()).where((name) => name.isNotEmpty).toSet();
    for (final id in ids.toSet()) {
      final assignments = await _database.watchPersonRoleAssignments(id).first;
      final remaining = assignments
          .where((assignment) => assignment.role == '出演者')
          .map((assignment) => assignment.person)
          .where((person) => !removing.contains(person.name.toLowerCase()))
          .toList();
      await _database.setPeopleForRole(id, '出演者', remaining);
    }
  }

  Future<void> batchSetStatus(Iterable<int> ids, String status) => _database.batchSetStatus(ids, status);
  Future<void> batchSetRating(Iterable<int> ids, int rating) => _database.batchSetRating(ids, rating);
  Future<void> batchSetFavorite(Iterable<int> ids, bool favorite) => _database.batchSetFavorite(ids, favorite);
  Future<void> batchDelete(Iterable<int> ids) async {
    for (final id in ids.toSet()) {
      await lifecycleStore.moveToTrash(id);
    }
  }

  Future<int> addPhoto({required String path, String? title, String? note, Iterable<String> tagNames = const []}) =>
      _database.addPhoto(path: path, title: title, note: note, tagNames: tagNames);
  Future<void> updatePhoto(PhotoRecord photo, {String? title, String? note, Iterable<String>? tagNames}) =>
      _database.updatePhoto(photo.id, title: title, note: note, tagNames: tagNames);
  Future<void> deletePhoto(PhotoRecord photo) async {
    await _database.deletePhoto(photo.id);
    await const PhotoStorageService().deleteManagedPhoto(photo.path);
  }
  Future<void> attachPhoto(BookmarkItem bookmark, PhotoRecord photo, {bool asCover = false}) =>
      _database.attachPhotoToBookmark(bookmark.id, photo.id, asCover: asCover);
  Future<void> attachPhotos(BookmarkItem bookmark, Iterable<PhotoRecord> photos, {PhotoRecord? coverPhoto}) =>
      _database.attachPhotosToBookmark(bookmark.id, photos.map((photo) => photo.id), coverPhotoId: coverPhoto?.id);
  Future<void> attachPhotosByBookmarkId(int bookmarkId, Iterable<PhotoRecord> photos, {PhotoRecord? coverPhoto}) =>
      _database.attachPhotosToBookmark(bookmarkId, photos.map((photo) => photo.id), coverPhotoId: coverPhoto?.id);
  Future<void> detachPhoto(BookmarkItem bookmark, PhotoRecord photo) => _database.detachPhotoFromBookmark(bookmark.id, photo.id);
  Future<void> setCoverPhoto(BookmarkItem bookmark, PhotoRecord photo) => _database.setCoverPhoto(bookmark.id, photo.id);
  Future<void> clearCoverPhoto(BookmarkItem bookmark) => _database.clearCoverPhoto(bookmark.id);

  Future<int> createPerson(String name, {String? note}) => _database.createPerson(name, note: note);
  Future<void> updatePerson(Person person, String name, String? note, {PhotoRecord? profilePhoto, bool updateProfilePhoto = false}) =>
      _database.updatePerson(person.id, name, note, profilePhotoId: profilePhoto?.id, updateProfilePhoto: updateProfilePhoto);
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
    bool includeDescendants = true,
    int? personFilterId,
    int? photoFilterId,
  }) async {
    final id = await _database.createSavedView(
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
      includeDescendants: includeDescendants,
      personFilterId: personFilterId,
      photoFilterId: photoFilterId,
    );
    await workspaceStore.assignSavedView(id, workspaceId);
    return id;
  }

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
    String statusFilter = '',
    int minRating = 0,
    bool includeDescendants = true,
    int? personFilterId,
    int? photoFilterId,
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
        includeDescendants: includeDescendants,
        personFilterId: personFilterId,
        photoFilterId: photoFilterId,
      );

  Future<int> deleteSavedView(int id) => _database.deleteSavedView(id);
}
