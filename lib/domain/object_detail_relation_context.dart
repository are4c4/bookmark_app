import '../data/relation_read_service.dart';
import 'object_detail_session.dart';

/// Shared Object detail state plus resolved outgoing Relations and Backlinks.
///
/// Relation lifecycle remains owned by the Relation lane; Object detail hosts
/// consume these stable resolved read models without duplicating graph queries.
class ObjectDetailRelationContext {
  const ObjectDetailRelationContext({
    required this.session,
    this.outgoing = const <ResolvedOutgoingRelation>[],
    this.backlinks = const <ResolvedRelationBacklink>[],
  });

  final ObjectDetailSession session;
  final List<ResolvedOutgoingRelation> outgoing;
  final List<ResolvedRelationBacklink> backlinks;
}
