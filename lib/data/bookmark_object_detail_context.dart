import 'bookmark_object_link_read_store.dart';
import 'bookmark_repository.dart';
import 'generic_database_store.dart';
import 'object_store.dart';

/// Focused migration boundary for presenting the canonical Object linked to a
/// legacy Bookmark.
///
/// Presentation code receives Object capabilities rather than reaching through
/// legacy repository internals to obtain the raw database. This context is
/// read-only with respect to Bookmark -> Object identity: resolving a missing
/// mirror never creates or repairs one.
class BookmarkObjectDetailContext {
  BookmarkObjectDetailContext._({
    required this.store,
    required this.objectStore,
    required BookmarkObjectLinkReadStore objectLinks,
  }) : _objectLinks = objectLinks;

  factory BookmarkObjectDetailContext.fromRepository(
    BookmarkRepository repository,
  ) {
    final database = repository.lifecycleStore.database;
    final store = GenericDatabaseStore(database);
    return BookmarkObjectDetailContext._(
      store: store,
      objectStore: ObjectStore(store),
      objectLinks: BookmarkObjectLinkReadStore(database),
    );
  }

  final GenericDatabaseStore store;
  final ObjectStore objectStore;
  final BookmarkObjectLinkReadStore _objectLinks;

  Future<int?> objectIdForBookmark({
    required int workspaceId,
    required int bookmarkId,
  }) =>
      _objectLinks.objectIdForBookmark(
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
      );
}
