import '../domain/object_model.dart';
import 'object_store.dart';

extension ObjectStoreRelationQueries on ObjectStore {
  /// Returns incoming relation edges for one specific Relation Property.
  ///
  /// This keeps Object-detail/backlink consumers from reimplementing edge
  /// filtering and preserves the relation index as the single query source.
  Future<List<ObjectRelationEdge>> backlinksForProperty({
    required int targetObjectId,
    required int propertyId,
  }) async {
    final edges = await backlinks(targetObjectId);
    return edges
        .where((edge) => edge.propertyId == propertyId)
        .toList(growable: false);
  }

  /// Returns outgoing relation edges for one specific Relation Property.
  Future<List<ObjectRelationEdge>> outgoingRelationsForProperty({
    required int sourceObjectId,
    required int propertyId,
  }) async {
    final edges = await outgoingRelations(sourceObjectId);
    return edges
        .where((edge) => edge.propertyId == propertyId)
        .toList(growable: false);
  }
}
