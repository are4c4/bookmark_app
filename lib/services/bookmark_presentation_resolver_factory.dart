import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import 'bookmark_url_resolver.dart';
import 'bookmark_visual_resolver.dart';

typedef BookmarkPresentationUrlSource = BookmarkUrlSource;
typedef BookmarkPresentationUrlResolve = BookmarkUrlResolve;

typedef BookmarkVisualResolve = Future<BookmarkVisualSource?> Function(
  BookmarkItem bookmark,
);

/// Centralizes the compatibility resolver graph used by legacy Bookmark hosts.
///
/// Presentation callers should not reach through [BookmarkRepository] to the
/// underlying database merely to construct canonical read-only URL/visual
/// resolvers. Keep that low-level composition in this boundary while Bookmark
/// compatibility hosts still exist.
class BookmarkPresentationResolverFactory {
  const BookmarkPresentationResolverFactory._();

  static BookmarkPresentationUrlResolve urlFor(BookmarkRepository repository) =>
      BookmarkUrlResolver(
        database: repository.workspaceStore.database,
        workspaceId: repository.workspaceId,
      ).resolve;

  static BookmarkVisualResolve visualFor(BookmarkRepository repository) =>
      BookmarkVisualResolver(
        database: repository.workspaceStore.database,
        workspaceId: repository.workspaceId,
      ).resolve;
}
