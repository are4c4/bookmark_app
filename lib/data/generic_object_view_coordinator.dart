import '../domain/object_group.dart';
import '../domain/object_model.dart';
import 'database_view_store.dart';
import 'generic_database_store.dart';
import 'object_view_projector.dart';

class GenericRecordGroup {
  const GenericRecordGroup({
    required this.bucket,
    required this.records,
  });

  final ObjectGroupBucket<AppObject> bucket;
  final List<GenericRecord> records;
}

class GenericObjectViewProjection {
  const GenericObjectViewProjection({
    required this.objectProjection,
    required this.records,
    required this.groups,
  });

  final ObjectViewProjection objectProjection;
  final List<GenericRecord> records;
  final List<GenericRecordGroup> groups;

  bool get isGrouped => objectProjection.isGrouped;
}

/// Bridges the Object-first query/group pipeline to the legacy GenericRecord
/// presentation layer.
///
/// GenericDatabasePage still edits and renders GenericRecord values today,
/// while filtering/sorting/grouping belongs to the Object layer. Keeping this
/// mapping in one place lets every layout share the same projection without
/// duplicating query logic or prematurely rewriting the editors.
class GenericObjectViewCoordinator {
  const GenericObjectViewCoordinator({
    this.projector = const ObjectViewProjector(),
  });

  final ObjectViewProjector projector;

  GenericObjectViewProjection project({
    required Iterable<AppObject> objects,
    required Iterable<GenericRecord> records,
    required DatabaseViewConfig view,
    ObjectViewValueResolver? valueResolver,
  }) {
    final projection = projector.project(
      objects: objects,
      view: view,
      valueResolver: valueResolver,
    );
    final recordById = <int, GenericRecord>{
      for (final record in records) record.id: record,
    };

    List<GenericRecord> recordsFor(Iterable<AppObject> source) => source
        .map((object) => recordById[object.id])
        .whereType<GenericRecord>()
        .toList(growable: false);

    return GenericObjectViewProjection(
      objectProjection: projection,
      records: recordsFor(projection.objects),
      groups: projection.groups
          .map(
            (bucket) => GenericRecordGroup(
              bucket: bucket,
              records: recordsFor(bucket.items),
            ),
          )
          .toList(growable: false),
    );
  }
}
