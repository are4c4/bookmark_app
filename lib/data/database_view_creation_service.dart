import '../database/database_definition.dart';
import 'database_view_store.dart';

/// Object-lane facade for the two adopted View creation paths.
///
/// The primary action duplicates the active View configuration while creating
/// a new persisted identity. The secondary blank path keeps the same Database
/// scope but starts from definition defaults with no View query/group state.
class DatabaseViewCreationService {
  const DatabaseViewCreationService(this.store);

  final DatabaseViewStore store;

  Future<DatabaseViewConfig> duplicateCurrent(DatabaseViewConfig source) async {
    final id = await store.duplicateView(source);
    return _find(
      workspaceId: source.workspaceId,
      databaseKey: source.databaseKey,
      id: id,
    );
  }

  Future<DatabaseViewConfig> createBlank({
    required int workspaceId,
    required DatabaseDefinition definition,
    String name = '新しいビュー',
  }) async {
    final id = await store.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: name,
      layoutType: definition.defaultLayout,
      filters: const <String, dynamic>{},
      sorts: const <dynamic>[],
      visibleProperties: definition.defaultVisibleProperties,
      propertyOrder: definition.defaultPropertyOrder,
      settings: const <String, dynamic>{},
    );
    return _find(
      workspaceId: workspaceId,
      databaseKey: definition.key,
      id: id,
    );
  }

  Future<DatabaseViewConfig> _find({
    required int workspaceId,
    required String databaseKey,
    required int id,
  }) async {
    final views = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: databaseKey,
    );
    return views.firstWhere((view) => view.id == id);
  }
}
