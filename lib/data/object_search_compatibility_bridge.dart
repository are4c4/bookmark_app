import 'bookmark_repository.dart';
import 'generic_database_store.dart';

/// Temporary compatibility bridge from the legacy root repository boundary to
/// canonical Object-search dependencies.
///
/// Presentation callers keep accepting [BookmarkRepository] while migration is
/// in progress, but they do not reach through it to AppDatabase directly.
class ObjectSearchCompatibilityContext {
  const ObjectSearchCompatibilityContext({
    required this.store,
    required this.workspaceId,
  });

  final GenericDatabaseStore store;
  final int workspaceId;
}

abstract final class ObjectSearchCompatibilityBridge {
  static ObjectSearchCompatibilityContext fromRepository(
    BookmarkRepository repository,
  ) {
    return ObjectSearchCompatibilityContext(
      store: GenericDatabaseStore(repository.workspaceStore.database),
      workspaceId: repository.workspaceId,
    );
  }
}
