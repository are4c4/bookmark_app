import '../data/relation_read_service.dart';

/// Builds deterministic user-facing search text from canonical outgoing
/// Relations.
///
/// Only resolved target Object titles are emitted. Relation/property/object ids
/// remain structural metadata and must never become searchable text. Callers
/// can explicitly opt a Relation Property out with `searchable: false`.
String buildObjectRelationSearchText(
  Iterable<ResolvedOutgoingRelation> relations,
) {
  final ordered = relations.toList(growable: false)
    ..sort((left, right) {
      final propertyOrder = left.property.id.compareTo(right.property.id);
      if (propertyOrder != 0) return propertyOrder;
      final positionOrder = left.edge.position.compareTo(right.edge.position);
      if (positionOrder != 0) return positionOrder;
      return left.edge.targetObjectId.compareTo(right.edge.targetObjectId);
    });

  final fragments = <String>[];
  for (final relation in ordered) {
    if (relation.property.config['searchable'] == false) continue;
    final label = relation.targetObject.title.trim();
    if (label.isEmpty) continue;
    fragments.add(label);
  }
  return fragments.join('\n');
}
