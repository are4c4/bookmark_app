import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/database_view_store.dart';
import '../data/workspace_store.dart';

typedef CollectionManagementRecord = CollectionRecord;
typedef CollectionManagementBookmark = BookmarkItem;

/// Application boundary for the legacy Collection management surface.
///
/// The Widget keeps interaction state while this service owns persistence
/// composition and Collection metadata mutations.
class CollectionManagementService {
  CollectionManagementService._({
    required AppDatabase database,
    required DatabaseViewStore viewStore,
  }) : _database = database,
       _viewStore = viewStore;

  factory CollectionManagementService.fromWorkspaceStore(
    WorkspaceStore workspaceStore,
  ) {
    final database = workspaceStore.database;
    return CollectionManagementService._(
      database: database,
      viewStore: DatabaseViewStore(database),
    );
  }

  final AppDatabase _database;
  final DatabaseViewStore _viewStore;

  /// Existing shared View widgets consume `DatabaseViewStore` directly.
  /// Keep that contract intact while hiding database construction from the page.
  DatabaseViewStore get databaseViewStore => _viewStore;

  Future<void> renameCollection(
    CollectionManagementRecord collection,
    String name,
  ) async {
    final value = name.trim();
    if (value.isEmpty || value == collection.name) return;
    await (_database.update(_database.collections)
          ..where((row) => row.id.equals(collection.id)))
        .write(CollectionsCompanion(name: Value(value)));
  }

  Future<void> saveCollectionNote(
    CollectionManagementRecord collection,
    String note,
  ) async {
    final value = note.trim();
    await (_database.update(_database.collections)
          ..where((row) => row.id.equals(collection.id)))
        .write(CollectionsCompanion(note: Value(value.isEmpty ? null : value)));
  }
}
