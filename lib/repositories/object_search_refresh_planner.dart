import '../data/object_store.dart';

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
}
