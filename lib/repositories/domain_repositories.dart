import '../data/app_database.dart';
import '../data/bookmark_attachment_store.dart';
import '../data/bookmark_repository.dart';
import '../data/pdf_annotation_store.dart';
import '../data/person_roles.dart';
import '../data/tag_group_store.dart';
import '../data/workspace_store.dart';
import 'backlink_repository.dart';
import 'full_text_search_repository.dart';

class WorkspaceRepository {
  const WorkspaceRepository(this._root);
  final BookmarkRepository _root;

  Stream<List<WorkspaceInfo>> watchAll() => _root.workspaceStore.watchWorkspaces();
  Future<List<WorkspaceInfo>> list() => _root.listWorkspaces();
  Future<int> create(String name, {String icon = '📁', int colorValue = 4288585374}) =>
      _root.createWorkspace(name, icon: icon, colorValue: colorValue);
  Future<void> update(WorkspaceInfo workspace, {String? name, String? icon, int? colorValue}) =>
      _root.updateWorkspace(workspace, name: name, icon: icon, colorValue: colorValue);
  Future<void> reorder(List<int> orderedIds) => _root.reorderWorkspaces(orderedIds);
  Future<void> delete(WorkspaceInfo workspace) => _root.deleteWorkspace(workspace);
  Future<void> setActive(WorkspaceInfo workspace) => _root.setActiveWorkspace(workspace);
  Future<void> moveBookmarks(Iterable<int> bookmarkIds, WorkspaceInfo workspace) =>
      _root.moveBookmarksToWorkspace(bookmarkIds, workspace);
}

class TagRepository {
  const TagRepository(this._root);
  final BookmarkRepository _root;

  Stream<List<Tag>> watchAll() => _root.watchTags();
  Future<int> create(String name, {Tag? parent}) => _root.createTag(name, parent: parent);
  Future<void> rename(Tag tag, String name) => _root.renameTag(tag, name);
  Future<void> setParent(Tag tag, Tag? parent) => _root.setTagParent(tag, parent);
  Future<void> delete(Tag tag) => _root.deleteTag(tag);
  Future<void> setForBookmark(BookmarkItem bookmark, Iterable<Tag> tags) =>
      _root.setBookmarkTagsFromDatabase(bookmark, tags);
}

class TagGroupRepository {
  TagGroupRepository(BookmarkRepository root) : _store = TagGroupStore(root.lifecycleStore.database);

  final TagGroupStore _store;

  Stream<List<TagGroupInfo>> watchAll() => _store.watchGroups();
  Stream<Map<int, int?>> watchAssignments() => _store.watchTagGroupIds();
  Future<List<TagGroupInfo>> list() => _store.listGroups();
  Future<int> create(String name) => _store.createGroup(name);
  Future<void> rename(TagGroupInfo group, String name) => _store.renameGroup(group.id, name);
  Future<void> delete(TagGroupInfo group) => _store.deleteGroup(group.id);
  Future<void> assign(Tag tag, TagGroupInfo? group) => _store.setTagGroup(tag.id, group?.id);
  Future<void> reorder(List<int> ids) => _store.reorderGroups(ids);
}

class PeopleRepository {
  const PeopleRepository(this._root);
  final BookmarkRepository _root;

  Stream<List<Person>> watchAll() => _root.watchPeople();
  Stream<List<PersonRoleAssignment>> watchRolesForBookmark(BookmarkItem bookmark) =>
      _root.watchPersonRoles(bookmark);
  Stream<List<PersonRoleAssignment>> watchRolesForPerson(Person person) =>
      _root.watchRolesForPerson(person);
  Stream<List<BookmarkItem>> watchBookmarksFor(Person person) =>
      _root.watchBookmarksForPerson(person);
  Future<int> create(String name, {String? note}) => _root.createPerson(name, note: note);
  Future<void> update(
    Person person,
    String name,
    String? note, {
    PhotoRecord? profilePhoto,
    bool updateProfilePhoto = false,
  }) =>
      _root.updatePerson(
        person,
        name,
        note,
        profilePhoto: profilePhoto,
        updateProfilePhoto: updateProfilePhoto,
      );
  Future<void> delete(Person person) => _root.deletePerson(person);
  Future<void> setForRole(BookmarkItem bookmark, String role, Iterable<Person> people) =>
      _root.setPeopleForRole(bookmark, role, people);
}

class PhotoRepository {
  const PhotoRepository(this._root);
  final BookmarkRepository _root;

  Stream<List<PhotoRecord>> watchAll() => _root.watchPhotos();
  Stream<List<BookmarkItem>> watchBookmarksFor(PhotoRecord photo) =>
      _root.watchBookmarksForPhoto(photo);
  Future<int> create({
    required String path,
    String? title,
    String? note,
    Iterable<String> tagNames = const [],
  }) =>
      _root.addPhoto(path: path, title: title, note: note, tagNames: tagNames);
  Future<void> update(
    PhotoRecord photo, {
    String? title,
    String? note,
    Iterable<String>? tagNames,
  }) =>
      _root.updatePhoto(photo, title: title, note: note, tagNames: tagNames);
  Future<void> delete(PhotoRecord photo) => _root.deletePhoto(photo);
  Future<void> attach(BookmarkItem bookmark, PhotoRecord photo, {bool asCover = false}) =>
      _root.attachPhoto(bookmark, photo, asCover: asCover);
  Future<void> detach(BookmarkItem bookmark, PhotoRecord photo) =>
      _root.detachPhoto(bookmark, photo);
}

class CollectionRepository {
  const CollectionRepository(this._root);
  final BookmarkRepository _root;

  Stream<List<CollectionRecord>> watchAll() => _root.watchCollections();
  Stream<List<BookmarkItem>> watchBookmarksFor(CollectionRecord collection) =>
      _root.watchBookmarksForCollection(collection);
  Future<int> create(String name, {String? note}) => _root.createCollection(name, note: note);
  Future<void> delete(CollectionRecord collection) => _root.deleteCollection(collection);
  Future<void> setForBookmark(BookmarkItem bookmark, Iterable<CollectionRecord> collections) =>
      _root.setBookmarkCollections(bookmark, collections);
}

class AttachmentRepository {
  AttachmentRepository(BookmarkRepository root)
      : _store = BookmarkAttachmentStore(root.lifecycleStore.database);

  final BookmarkAttachmentStore _store;

  Stream<List<BookmarkAttachment>> watchForBookmark(int bookmarkId) =>
      _store.watchForBookmark(bookmarkId);
  Future<List<BookmarkAttachment>> listForBookmark(int bookmarkId) =>
      _store.listForBookmark(bookmarkId);
  Future<int> add({
    required int bookmarkId,
    required String fileName,
    required String path,
    required String kind,
    required int sizeBytes,
  }) =>
      _store.add(
        bookmarkId: bookmarkId,
        fileName: fileName,
        path: path,
        kind: kind,
        sizeBytes: sizeBytes,
      );
  Future<void> remove(int id) => _store.remove(id);
}

class PdfAnnotationRepository {
  PdfAnnotationRepository(BookmarkRepository root)
      : _store = PdfAnnotationStore(root.lifecycleStore.database);

  final PdfAnnotationStore _store;

  Stream<List<PdfAnnotationRecord>> watchForAttachment(int attachmentId) =>
      _store.watchForAttachment(attachmentId);
  Future<List<PdfAnnotationRecord>> listForAttachment(int attachmentId) =>
      _store.listForAttachment(attachmentId);
  Future<void> add({
    required int attachmentId,
    required int pageNumber,
    required String kind,
    String selectedText = '',
    String note = '',
  }) =>
      _store.add(
        attachmentId: attachmentId,
        pageNumber: pageNumber,
        kind: kind,
        selectedText: selectedText,
        note: note,
      );
  Future<void> remove(int id) => _store.remove(id);
}

class BookmarkLifecycleRepository {
  const BookmarkLifecycleRepository(this._root);
  final BookmarkRepository _root;

  Stream<List<BookmarkItem>> watchAll() => _root.watchAll();
  Stream<List<BookmarkItem>> watchInbox() => _root.watchInbox();
  Stream<List<BookmarkItem>> watchTrash() => _root.watchTrash();
  Future<void> setInbox(BookmarkItem bookmark, bool value) => _root.setInbox(bookmark, value);
  Future<void> moveToTrash(BookmarkItem bookmark) => _root.moveToTrash(bookmark);
  Future<void> restore(BookmarkItem bookmark) => _root.restoreFromTrash(bookmark);
  Future<void> permanentlyDelete(BookmarkItem bookmark) => _root.permanentDelete(bookmark);
}

class AppRepositories {
  AppRepositories._(this.bookmarks)
      : workspaces = WorkspaceRepository(bookmarks),
        tags = TagRepository(bookmarks),
        tagGroups = TagGroupRepository(bookmarks),
        people = PeopleRepository(bookmarks),
        photos = PhotoRepository(bookmarks),
        collections = CollectionRepository(bookmarks),
        attachments = AttachmentRepository(bookmarks),
        pdfAnnotations = PdfAnnotationRepository(bookmarks),
        lifecycle = BookmarkLifecycleRepository(bookmarks),
        search = FullTextSearchRepository(bookmarks),
        backlinks = BacklinkRepository(bookmarks);

  factory AppRepositories(BookmarkRepository root) => AppRepositories._(root);

  final BookmarkRepository bookmarks;
  final WorkspaceRepository workspaces;
  final TagRepository tags;
  final TagGroupRepository tagGroups;
  final PeopleRepository people;
  final PhotoRepository photos;
  final CollectionRepository collections;
  final AttachmentRepository attachments;
  final PdfAnnotationRepository pdfAnnotations;
  final BookmarkLifecycleRepository lifecycle;
  final FullTextSearchRepository search;
  final BacklinkRepository backlinks;
}
