import '../data/object_store.dart';
import '../data/relation_read_service.dart';

/// Computes the canonical Object rows whose search projection can be affected
/// when one Object's display label changes.
///
/// Relation labels are denormalized into source Object search rows. Renaming a
/// target therefore requires refreshing the target itself plus every source
/// that currently points at it. For deletion, callers must collect this plan
/// before deleting the target because Relation edges cascade with the Object.
class ObjectSearchRefreshPlanner {
  const ObjectSearchRefreshPlanner(this.objectStore);

  final ObjectStore objectStore;

  Future<List<int>> forObjectLabelChange(int objectId) async {
    final affected = <int>{objectId};
    for (final edge in await objectStore.backlinks(objectId)) {
      affected.add(edge.sourceObjectId);
    }
    final dependents = affected.where((id) => id != objectId).toList()..sort();
    return List<int>.unmodifiable(<int>[objectId, ...dependents]);
  }

  /// Plans the focused refresh required after returning from one Object detail.
  ///
  /// Detail actions can affect more than the opened Object. For example, URL
  /// Value promotion can create or update a reusable Weblink and then relate it
  /// to the source. Refresh the opened Object, its label dependents, every
  /// trustworthy current outgoing Relation target, and each target's label
  /// dependents without rebuilding the whole workspace.
  ///
  /// Relation targets are enumerated through the canonical fail-closed reader;
  /// they are not interpreted as search text here. If related ObjectType schema
  /// decoding itself fails, Search keeps the source refresh and simply omits
  /// optional target expansion, matching the existing source-local corruption
  /// boundary.
  Future<List<int>> forDetailReturn({
    required int objectTypeId,
    required int objectId,
  }) async {
    final roots = <int>{objectId};
    try {
      final outgoing = await RelationReadService(objectStore).outgoing(
        sourceObjectTypeId: objectTypeId,
        sourceObjectId: objectId,
      );
      for (final relation in outgoing) {
        roots.add(relation.targetObject.id);
      }
    } on FormatException {
      // A corrupt related ObjectType must not turn an otherwise valid detail
      // return into a workspace-wide Search failure. The opened Object still
      // refreshes and its Search projection will independently fail closed at
      // the relation_labels contribution boundary.
    }

    final affected = <int>{};
    final relatedRoots = roots.where((id) => id != objectId).toList()..sort();
    for (final rootId in <int>[objectId, ...relatedRoots]) {
      affected.addAll(await forObjectLabelChange(rootId));
    }

    final additional = affected.where((id) => id != objectId).toList()..sort();
    return List<int>.unmodifiable(<int>[objectId, ...additional]);
  }
}
