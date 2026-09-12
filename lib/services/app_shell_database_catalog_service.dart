import 'package:drift/drift.dart';

import '../data/generic_database_store.dart';
import '../data/object_type_template_store.dart';
import '../data/workspace_store.dart';

typedef AppShellDatabaseRecord = GenericDatabaseDefinitionRecord;

/// Application boundary for the generic Database catalog owned by AppShell.
///
/// Presentation supplies the workspace boundary and asks for catalog-level
/// operations. Store/template composition stays here instead of reaching
/// through `WorkspaceStore.database` from the Widget.
class AppShellDatabaseCatalogService {
  AppShellDatabaseCatalogService._({
    required GenericDatabaseStore store,
    required ObjectTypeTemplateStore templates,
  }) : _store = store,
       _templates = templates;

  factory AppShellDatabaseCatalogService.fromWorkspaceStore(
    WorkspaceStore workspaceStore,
  ) {
    final store = GenericDatabaseStore(workspaceStore.database);
    return AppShellDatabaseCatalogService._(
      store: store,
      templates: ObjectTypeTemplateStore(store),
    );
  }

  final GenericDatabaseStore _store;
  final ObjectTypeTemplateStore _templates;

  Future<List<AppShellDatabaseRecord>> listDatabases({
    required int workspaceId,
  }) {
    return _store.listDatabases(workspaceId);
  }

  /// Resolves one registered system ObjectType to its canonical generic
  /// Database without relying on its user-facing/display name.
  Future<AppShellDatabaseRecord?> findSystemDatabase({
    required int workspaceId,
    required String systemKey,
  }) async {
    await _store.ensureSchema();
    final hasSystemRegistry = await _store.database
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'system_object_types' LIMIT 1",
        )
        .getSingleOrNull();
    if (hasSystemRegistry == null) return null;

    final row = await _store.database.customSelect(
      '''SELECT d.id, d.workspace_id, d.name, d.icon, d.sort_order
         FROM generic_databases d
         INNER JOIN system_object_types s ON s.object_type_id = d.id
         WHERE d.workspace_id = ? AND s.system_key = ?
         LIMIT 1''',
      variables: [
        Variable<int>(workspaceId),
        Variable<String>(systemKey),
      ],
    ).getSingleOrNull();
    if (row == null) return null;

    return AppShellDatabaseRecord(
      id: row.read<int>('id'),
      workspaceId: row.read<int>('workspace_id'),
      name: row.read<String>('name'),
      icon: row.read<String>('icon'),
      sortOrder: row.read<int>('sort_order'),
    );
  }

  Future<int> createEmptyDatabase({
    required int workspaceId,
    required String name,
  }) {
    return _store.createDatabase(workspaceId: workspaceId, name: name);
  }

  Future<int> createTemplateDatabase({
    required int workspaceId,
    required ObjectTypeTemplate template,
    required String name,
  }) {
    return _templates.createFromTemplate(
      workspaceId: workspaceId,
      template: template,
      name: name,
    );
  }

  /// Existing `HomeStartPage` still consumes the lower-level store directly.
  /// Keep that separate presentation contract intact in this focused slice;
  /// AppShell itself no longer constructs or reaches through to the store.
  GenericDatabaseStore get homeStartStore => _store;
}
