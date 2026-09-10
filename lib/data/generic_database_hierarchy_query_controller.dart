import '../domain/object_model.dart';
import 'tag_hierarchy_query_context_service.dart';

/// Keeps GenericDatabasePage's hierarchy query capability in one small,
/// reusable runtime boundary while the page owns only presentation state.
class GenericDatabaseHierarchyQueryController {
  GenericDatabaseHierarchyQueryController(this.queryContextService);

  final TagHierarchyQueryContextService queryContextService;

  Future<TagHierarchyQueryContext> load({
    required int workspaceId,
    required AppObjectType? objectType,
  }) async {
    if (objectType == null) return TagHierarchyQueryContext.unavailable;
    try {
      return await queryContextService.loadForObjectType(
        workspaceId: workspaceId,
        objectType: objectType,
      );
    } catch (_) {
      return TagHierarchyQueryContext.unavailable;
    }
  }

  Future<Set<int>> hierarchyAwarePropertyIds({
    required int workspaceId,
    required AppObjectType objectType,
  }) async {
    final context = await load(
      workspaceId: workspaceId,
      objectType: objectType,
    );
    return context.hierarchyAwarePropertyIds;
  }
}
