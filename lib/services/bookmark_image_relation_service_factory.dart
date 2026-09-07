import '../data/bookmark_repository.dart';
import 'bookmark_image_relation_service.dart';

/// Production composition boundary for Bookmark image Relations.
///
/// Presentation receives a BookmarkRepository but does not reach through its
/// WorkspaceStore to the database directly. The compatibility database access
/// stays in the service layer while the widget consumes canonical operations.
BookmarkImageRelationService createBookmarkImageRelationService(
  BookmarkRepository repository,
) =>
    BookmarkImageRelationService(repository.workspaceStore.database);
