import 'object_detail_relation_context.dart';
import 'object_detail_session_loader.dart';
import 'relation_read_service.dart';

/// Adds resolved Relation graph context to the shared Object detail session.
class ObjectDetailRelationContextLoader {
  const ObjectDetailRelationContextLoader({
    required this.sessionLoader,
    required this.relationReads,
  });

  final ObjectDetailSessionLoader sessionLoader;
  final RelationReadService relationReads;

  Future<ObjectDetailRelationContext?> load({
    required int objectTypeId,
    required int objectId,
  }) async {
    final session = await sessionLoader.load(
      objectTypeId: objectTypeId,
      objectId: objectId,
    );
    if (session == null) return null;

    final neighborhood = await relationReads.neighborhood(
      workspaceId: session.content.objectType.workspaceId,
      objectTypeId: objectTypeId,
      objectId: objectId,
    );
    return ObjectDetailRelationContext(
      session: session,
      neighborhood: neighborhood,
    );
  }
}
