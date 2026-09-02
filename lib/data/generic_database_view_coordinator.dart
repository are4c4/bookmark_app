import '../domain/object_model.dart';
import 'database_view_query_adapter.dart';
import 'database_view_store.dart';
import 'generic_database_store.dart';
import 'object_view_projector.dart';

typedef DatabaseViewSaver = Future<void> Function(DatabaseViewConfig view);

class GenericDatabaseViewProjection {
  const GenericDatabaseViewProjection({
    required this.objectProjection,
    required this.records,
  });

  final ObjectViewProjection objectProjection;
  final List<GenericRecord> records;
}

/// Integration layer between generic database storage records and the
/// Object-centric view/query pipeline.
///
/// Keeping this outside the page means Gallery/List/Table/Board can share the
/// exact same projected ordering and filtering while the existing record-based
/// editors are migrated incrementally.
class GenericDatabaseViewCoordinator {
  const GenericDatabaseViewCoordinator({
    this.projector = const ObjectViewProjector(),
    this.queryAdapter = const DatabaseViewQueryAdapter(),
  });

  final ObjectViewProjector projector;
  final DatabaseViewQueryAdapter queryAdapter;

  GenericDatabaseViewProjection project({
    required Iterable<AppObject> objects,
    required Iterable<GenericRecord> records,
    required DatabaseViewConfig view,
    Map<int, Map<int, dynamic>> computedValues = const {},
  }) {
    final projection = projector.project(
      objects: objects,
      view: view,
      valueResolver: (object, propertyId) {
        if (propertyId == null) return object.title;
        final computedForObject = computedValues[object.id];
        if (computedForObject != null &&
            computedForObject.containsKey(propertyId)) {
          return computedForObject[propertyId];
        }
        return object.values[propertyId];
      },
    );

    final recordsById = <int, GenericRecord>{
      for (final record in records) record.id: record,
    };
    final projectedRecords = projection.objects
        .map((object) => recordsById[object.id])
        .whereType<GenericRecord>()
        .toList(growable: false);

    return GenericDatabaseViewProjection(
      objectProjection: projection,
      records: projectedRecords,
    );
  }

  DatabaseViewConfig withSearch(DatabaseViewConfig view, String query) =>
      queryAdapter.encode(view, searchQuery: query);

  Future<DatabaseViewConfig> persist(
    DatabaseViewConfig next,
    DatabaseViewSaver save,
  ) async {
    await save(next);
    return next;
  }
}
