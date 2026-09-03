import '../../..//data/database_view_store.dart';
import '../../..//data/generic_database_store.dart';
import 'widgets/object_body_database_view_reference_picker.dart';

/// Loads explicit Database/View Body-reference candidates from the active
/// workspace. The catalog mirrors the user-facing custom Database list and
/// never creates or mutates a View while preparing picker choices.
class ObjectBodyDatabaseViewReferenceCatalog {
  const ObjectBodyDatabaseViewReferenceCatalog({
    required this.databaseStore,
    required this.viewStore,
  });

  final GenericDatabaseStore databaseStore;
  final DatabaseViewStore viewStore;

  Future<List<ObjectBodyDatabaseViewReferenceCandidate>> load({
    required int workspaceId,
  }) async {
    final databases = await databaseStore.listDatabases(workspaceId);
    final candidates = <ObjectBodyDatabaseViewReferenceCandidate>[];

    for (final database in databases) {
      candidates.add(
        ObjectBodyDatabaseViewReferenceCandidate(
          databaseId: database.id,
          databaseName: database.name,
          databaseIcon: database.icon,
        ),
      );
      final views = await viewStore.listViews(
        workspaceId: workspaceId,
        databaseKey: database.databaseKey,
      );
      for (final view in views) {
        candidates.add(
          ObjectBodyDatabaseViewReferenceCandidate(
            databaseId: database.id,
            databaseName: database.name,
            databaseIcon: database.icon,
            viewId: view.id,
            viewName: view.name,
          ),
        );
      }
    }

    return List<ObjectBodyDatabaseViewReferenceCandidate>.unmodifiable(
      candidates,
    );
  }
}
