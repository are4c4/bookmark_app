import 'database_collection_resolver.dart';
import 'database_view_store.dart';
import 'object_view_projector.dart';

class DatabaseCollectionViewProjection {
  const DatabaseCollectionViewProjection({
    required this.collection,
    required this.view,
  });

  final ResolvedDatabaseCollection collection;
  final ObjectViewProjection view;
}

/// Applies Database membership first and View presentation/query second.
///
/// Keeping this orchestration explicit prevents View filters from accidentally
/// becoming membership rules or collection filters from being persisted as
/// transient View state.
class DatabaseCollectionViewProjector {
  const DatabaseCollectionViewProjector({
    required this.collectionResolver,
    this.viewProjector = const ObjectViewProjector(),
  });

  final DatabaseCollectionResolver collectionResolver;
  final ObjectViewProjector viewProjector;

  Future<DatabaseCollectionViewProjection?> project({
    required int databaseId,
    required DatabaseViewConfig view,
    ObjectViewValueResolver? valueResolver,
  }) async {
    final collection = await collectionResolver.resolve(databaseId);
    if (collection == null) return null;

    if (view.workspaceId != collection.definition.workspaceId ||
        view.databaseKey != 'custom:$databaseId') {
      throw ArgumentError.value(
        view.id,
        'view',
        'View must belong to the Database collection being projected.',
      );
    }

    final projection = viewProjector.project(
      objects: collection.objects,
      view: view,
      valueResolver: valueResolver,
    );
    return DatabaseCollectionViewProjection(
      collection: collection,
      view: projection,
    );
  }
}
