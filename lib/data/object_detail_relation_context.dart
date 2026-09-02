import '../domain/object_detail_session.dart';
import 'relation_read_service.dart';

/// Shared Object detail state plus resolved outgoing Relations and Backlinks.
///
/// Relation lifecycle remains owned by the Relation lane; Object detail hosts
/// consume this stable read model without duplicating graph queries.
class ObjectDetailRelationContext {
  const ObjectDetailRelationContext({
    required this.session,
    required this.neighborhood,
  });

  final ObjectDetailSession session;
  final RelationNeighborhood neighborhood;

  List<ResolvedOutgoingRelation> get outgoing => neighborhood.outgoing;
  List<ResolvedRelationBacklink> get backlinks => neighborhood.backlinks;
}
