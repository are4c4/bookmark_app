import '../domain/object_history_checkpoint.dart';
import '../domain/object_history_relation.dart';
import 'generic_database_store.dart';
import 'object_history_checkpoint_store.dart';
import 'object_history_relation_store.dart';

/// A-owned composition boundary for one durable whole-Object history capture.
///
/// A checkpoint persistence and B-owned Relation evidence remain separate
/// stores and authorities. This coordinator only guarantees that the immutable
/// evidence for one Object revision is validated and appended atomically.
class ObjectHistoryCaptureCoordinator {
  ObjectHistoryCaptureCoordinator(this._genericStore)
    : _checkpointStore = ObjectHistoryCheckpointStore(_genericStore),
      _relationStore = ObjectHistoryRelationStore(_genericStore);

  final GenericDatabaseStore _genericStore;
  final ObjectHistoryCheckpointStore _checkpointStore;
  final ObjectHistoryRelationStore _relationStore;

  /// Appends one complete immutable history checkpoint.
  ///
  /// Returns `true` when either A or B persistence appended new evidence and
  /// `false` for an exact idempotent retry. Input-shape mismatches are rejected
  /// before either store is touched. Store conflicts fail closed inside the
  /// enclosing transaction so a partial whole-Object checkpoint cannot remain.
  Future<bool> append({
    required ObjectHistoryCheckpointPayload checkpoint,
    required List<ObjectHistoryRelationSnapshot> relationSnapshots,
  }) async {
    _validateRelationEvidence(checkpoint, relationSnapshots);

    return _genericStore.database.transaction(() async {
      final checkpointChanged = await _checkpointStore.append(checkpoint);
      var relationChanged = false;
      for (final snapshot in relationSnapshots) {
        final changed = await _relationStore.append(
          revisionId: checkpoint.entry.revisionId,
          snapshot: snapshot,
        );
        relationChanged = relationChanged || changed;
      }
      return checkpointChanged || relationChanged;
    });
  }
}

void _validateRelationEvidence(
  ObjectHistoryCheckpointPayload checkpoint,
  List<ObjectHistoryRelationSnapshot> relationSnapshots,
) {
  final objectId = checkpoint.entry.objectId;
  final requiredPropertyIds = <int>{
    for (final requirement in checkpoint.relationRequirements)
      requirement.propertyId,
  };
  final snapshotPropertyIds = <int>{};

  for (final snapshot in relationSnapshots) {
    if (snapshot.sourceObjectId != objectId) {
      throw ArgumentError.value(
        snapshot.sourceObjectId,
        'relationSnapshots',
        'Relation history evidence must belong to Object $objectId.',
      );
    }
    if (!snapshotPropertyIds.add(snapshot.propertyId)) {
      throw ArgumentError.value(
        snapshot.propertyId,
        'relationSnapshots',
        'Whole-Object history cannot contain duplicate Relation Properties.',
      );
    }
  }

  final missing = requiredPropertyIds.difference(snapshotPropertyIds);
  final extra = snapshotPropertyIds.difference(requiredPropertyIds);
  if (missing.isNotEmpty || extra.isNotEmpty) {
    throw ArgumentError.value(
      relationSnapshots,
      'relationSnapshots',
      'Relation history evidence must exactly match checkpoint Relation '
          'requirements (missing: ${missing.toList()..sort()}, '
          'extra: ${extra.toList()..sort()}).',
    );
  }
}
