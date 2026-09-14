import '../domain/object_history_checkpoint.dart';
import '../domain/object_history_relation.dart';
import 'generic_database_store.dart';
import 'object_history_checkpoint_store.dart';
import 'object_history_relation_store.dart';

/// Immutable restart-safe evidence for one complete historical Object revision.
///
/// The A-owned checkpoint remains separate from B-owned Relation snapshots. This
/// value only proves that both persisted stores contain a coherent historical
/// revision; it grants no authority to mutate current Object or Relation state.
class ObjectHistoryWholeCheckpoint {
  ObjectHistoryWholeCheckpoint({
    required this.checkpoint,
    required List<ObjectHistoryRelationSnapshot> relationSnapshots,
  }) : relationSnapshots = List<ObjectHistoryRelationSnapshot>.unmodifiable(
         relationSnapshots,
       );

  final ObjectHistoryCheckpointPayload checkpoint;
  final List<ObjectHistoryRelationSnapshot> relationSnapshots;
}

/// A-owned read composition boundary for restart-safe whole-Object history.
///
/// Relation evidence is loaded only through B's persisted history store. The
/// loader validates that the exact Relation Property set required by the A
/// checkpoint is present before exposing a restore input.
class ObjectHistoryCheckpointLoader {
  ObjectHistoryCheckpointLoader(this._genericStore)
    : _checkpointStore = ObjectHistoryCheckpointStore(_genericStore),
      _relationStore = ObjectHistoryRelationStore(_genericStore);

  final GenericDatabaseStore _genericStore;
  final ObjectHistoryCheckpointStore _checkpointStore;
  final ObjectHistoryRelationStore _relationStore;

  Future<ObjectHistoryWholeCheckpoint?> load({
    required int objectId,
    required int revisionId,
  }) async {
    final checkpoint = await _checkpointStore.load(
      objectId: objectId,
      revisionId: revisionId,
    );
    if (checkpoint == null) return null;

    return _genericStore.database.transaction(() async {
      final relations = await _relationStore.listForRevision(
        sourceObjectId: objectId,
        revisionId: revisionId,
      );
      _validateRelationEvidence(checkpoint, relations);
      return ObjectHistoryWholeCheckpoint(
        checkpoint: checkpoint,
        relationSnapshots: relations,
      );
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
      throw StateError(
        'Relation history evidence for Property ${snapshot.propertyId} belongs '
        'to Object ${snapshot.sourceObjectId}, expected Object $objectId.',
      );
    }
    if (!snapshotPropertyIds.add(snapshot.propertyId)) {
      throw StateError(
        'Whole-Object history contains duplicate Relation Property '
        '${snapshot.propertyId}.',
      );
    }
  }

  final missing = requiredPropertyIds.difference(snapshotPropertyIds);
  final extra = snapshotPropertyIds.difference(requiredPropertyIds);
  if (missing.isNotEmpty || extra.isNotEmpty) {
    throw StateError(
      'Persisted Relation history does not match checkpoint requirements '
      '(missing: ${missing.toList()..sort()}, '
      'extra: ${extra.toList()..sort()}).',
    );
  }
}
