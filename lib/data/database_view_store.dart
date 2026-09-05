import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import '../database/database_definition.dart';
import 'app_database.dart';

class DatabaseViewConfig {
  const DatabaseViewConfig({
    required this.id,
    required this.workspaceId,
    required this.databaseKey,
    required this.name,
    required this.layoutType,
    required this.filters,
    required this.sorts,
    required this.visibleProperties,
    required this.propertyOrder,
    required this.settings,
    required this.sortOrder,
  });

  final int id;
  final int workspaceId;
  final String databaseKey;
  final String name;
  final String layoutType;
  final Map<String, dynamic> filters;
  final List<dynamic> sorts;
  final List<String> visibleProperties;
  final List<String> propertyOrder;
  final Map<String, dynamic> settings;
  final int sortOrder;

  DatabaseViewConfig copyWith({
    String? name,
    String? layoutType,
    Map<String, dynamic>? filters,
    List<dynamic>? sorts,
    List<String>? visibleProperties,
    List<String>? propertyOrder,
    Map<String, dynamic>? settings,
    int? sortOrder,
  }) =>
      DatabaseViewConfig(
        id: id,
        workspaceId: workspaceId,
        databaseKey: databaseKey,
        name: name ?? this.name,
        layoutType: layoutType ?? this.layoutType,
        filters: filters ?? this.filters,
        sorts: sorts ?? this.sorts,
        visibleProperties: visibleProperties ?? this.visibleProperties,
        propertyOrder: propertyOrder ?? this.propertyOrder,
        settings: settings ?? this.settings,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

class DatabaseViewStore {
  DatabaseViewStore(this.database);

  final AppDatabase database;
  Future<void>? _schemaReady;

  Future<void> _ensureSchema() => _schemaReady ??= database.transaction(() async {
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS database_views (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
            database_key TEXT NOT NULL,
            name TEXT NOT NULL,
            layout_type TEXT NOT NULL DEFAULT 'gallery',
            filters_json TEXT NOT NULL DEFAULT '{}',
            sorts_json TEXT NOT NULL DEFAULT '[]',
            visible_properties TEXT NOT NULL DEFAULT '',
            property_order TEXT NOT NULL DEFAULT '',
            settings_json TEXT NOT NULL DEFAULT '{}',
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await database.customStatement(
          'CREATE INDEX IF NOT EXISTS database_views_scope_idx '
          'ON database_views(workspace_id, database_key, sort_order, id)',
        );
      });

  void _debugDecodeFailure(
    String valueKind,
    Object error,
    StackTrace stackTrace,
  ) {
    assert(() {
      developer.log(
        'DatabaseViewStore: invalid persisted $valueKind JSON; using empty fallback.',
        name: 'bookmark_app.database_view_store',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }());
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (error, stackTrace) {
      _debugDecodeFailure('map', error, stackTrace);
      return <String, dynamic>{};
    }
  }

  List<dynamic> _decodeList(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is List ? value : <dynamic>[];
    } catch (error, stackTrace) {
      _debugDecodeFailure('list', error, stackTrace);
      return <dynamic>[];
    }
  }

  List<String> _decodeCsv(String raw) => raw
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  DatabaseViewConfig _fromRow(QueryRow row) => DatabaseViewConfig(
        id: row.read<int>('id'),
        workspaceId: row.read<int>('workspace_id'),
        databaseKey: row.read<String>('database_key'),
        name: row.read<String>('name'),
        layoutType: row.read<String>('layout_type'),
        filters: _decodeMap(row.read<String>('filters_json')),
        sorts: _decodeList(row.read<String>('sorts_json')),
        visibleProperties: _decodeCsv(row.read<String>('visible_properties')),
        propertyOrder: _decodeCsv(row.read<String>('property_order')),
        settings: _decodeMap(row.read<String>('settings_json')),
        sortOrder: row.read<int>('sort_order'),
      );

  Future<List<DatabaseViewConfig>> listViews({
    required int workspaceId,
    required String databaseKey,
  }) async {
    await _ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT id, workspace_id, database_key, name, layout_type,
             filters_json, sorts_json, visible_properties, property_order,
             settings_json, sort_order
      FROM database_views
      WHERE workspace_id = ? AND database_key = ?
      ORDER BY sort_order, id
      ''',
      variables: [Variable<int>(workspaceId), Variable<String>(databaseKey)],
    ).get();
    return rows.map(_fromRow).toList();
  }

  Future<DatabaseViewConfig> ensureDefaultView({
    required int workspaceId,
    required DatabaseDefinition definition,
  }) async {
    final existing = await listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    if (existing.isNotEmpty) return existing.first;
    final id = await createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'すべて',
      layoutType: definition.defaultLayout,
    );
    return (await listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .firstWhere((view) => view.id == id);
  }

  Future<int> createView({
    required int workspaceId,
    required DatabaseDefinition definition,
    required String name,
    String? layoutType,
    Map<String, dynamic> filters = const {},
    List<dynamic> sorts = const [],
    List<String>? visibleProperties,
    List<String>? propertyOrder,
    Map<String, dynamic> settings = const {},
  }) async {
    await _ensureSchema();
    final views = await listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    final nextOrder = views.isEmpty
        ? 0
        : views.map((view) => view.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final title = name.trim().isEmpty ? '新しいビュー' : name.trim();
    await database.customStatement(
      '''
      INSERT INTO database_views(
        workspace_id, database_key, name, layout_type, filters_json,
        sorts_json, visible_properties, property_order, settings_json,
        sort_order
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        workspaceId,
        definition.key,
        title,
        layoutType ?? definition.defaultLayout,
        jsonEncode(filters),
        jsonEncode(sorts),
        (visibleProperties ?? definition.defaultVisibleProperties).join(','),
        (propertyOrder ?? definition.defaultPropertyOrder).join(','),
        jsonEncode(settings),
        nextOrder,
      ],
    );
    final row = await database.customSelect(
      'SELECT id FROM database_views WHERE workspace_id = ? AND database_key = ? ORDER BY id DESC LIMIT 1',
      variables: [Variable<int>(workspaceId), Variable<String>(definition.key)],
    ).getSingle();
    return row.read<int>('id');
  }

  Future<void> updateView(DatabaseViewConfig view) async {
    await _ensureSchema();
    await database.customStatement(
      '''
      UPDATE database_views
      SET name = ?, layout_type = ?, filters_json = ?, sorts_json = ?,
          visible_properties = ?, property_order = ?, settings_json = ?,
          sort_order = ?
      WHERE id = ?
      ''',
      [
        view.name.trim().isEmpty ? '新しいビュー' : view.name.trim(),
        view.layoutType,
        jsonEncode(view.filters),
        jsonEncode(view.sorts),
        view.visibleProperties.join(','),
        view.propertyOrder.join(','),
        jsonEncode(view.settings),
        view.sortOrder,
        view.id,
      ],
    );
  }

  Future<void> renameView(int id, String name) async {
    await _ensureSchema();
    final value = name.trim();
    if (value.isEmpty) return;
    await database.customStatement(
      'UPDATE database_views SET name = ? WHERE id = ?',
      [value, id],
    );
  }

  Future<int> duplicateView(DatabaseViewConfig view) async {
    await _ensureSchema();
    final views = await listViews(
      workspaceId: view.workspaceId,
      databaseKey: view.databaseKey,
    );
    final nextOrder = views.isEmpty
        ? 0
        : views.map((item) => item.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await database.customStatement(
      '''
      INSERT INTO database_views(
        workspace_id, database_key, name, layout_type, filters_json,
        sorts_json, visible_properties, property_order, settings_json,
        sort_order
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        view.workspaceId,
        view.databaseKey,
        '${view.name} のコピー',
        view.layoutType,
        jsonEncode(view.filters),
        jsonEncode(view.sorts),
        view.visibleProperties.join(','),
        view.propertyOrder.join(','),
        jsonEncode(view.settings),
        nextOrder,
      ],
    );
    final row = await database.customSelect(
      'SELECT id FROM database_views WHERE workspace_id = ? AND database_key = ? ORDER BY id DESC LIMIT 1',
      variables: [Variable<int>(view.workspaceId), Variable<String>(view.databaseKey)],
    ).getSingle();
    return row.read<int>('id');
  }

  Future<void> deleteView(int id) async {
    await _ensureSchema();
    await database.customStatement('DELETE FROM database_views WHERE id = ?', [id]);
  }

  Future<void> reorderViews(List<DatabaseViewConfig> ordered) async {
    await _ensureSchema();
    await database.transaction(() async {
      for (var i = 0; i < ordered.length; i++) {
        await database.customStatement(
          'UPDATE database_views SET sort_order = ? WHERE id = ?',
          [i, ordered[i].id],
        );
      }
    });
  }

  /// Imports legacy bookmark saved views once. Existing generic bookmark views
  /// are never overwritten.
  Future<void> importLegacyBookmarkViews({required int workspaceId}) async {
    await _ensureSchema();
    final existing = await listViews(workspaceId: workspaceId, databaseKey: 'bookmarks');
    if (existing.isNotEmpty) return;

    final rows = await database.customSelect(
      '''
      SELECT sv.id, sv.name, sv.layout_type, sv.search_query,
             sv.favorites_only, sv.tag_match_mode, sv.sort_field,
             sv.sort_direction, sv.visible_properties, sv.status_filter,
             sv.min_rating, sv.include_descendants, sv.person_filter_id,
             sv.photo_filter_id
      FROM saved_views sv
      LEFT JOIN saved_view_workspace sw ON sw.saved_view_id = sv.id
      WHERE sw.workspace_id = ? OR sw.workspace_id IS NULL
      ORDER BY sv.created_at, sv.id
      ''',
      variables: [Variable<int>(workspaceId)],
    ).get();

    if (rows.isEmpty) return;
    for (final row in rows) {
      final legacyId = row.read<int>('id');
      final tagRows = await database.customSelect(
        'SELECT tag_id FROM saved_view_tags WHERE saved_view_id = ?',
        variables: [Variable<int>(legacyId)],
      ).get();
      final filters = <String, dynamic>{
        'query': row.read<String>('search_query'),
        'favoritesOnly': row.read<bool>('favorites_only'),
        'tagIds': tagRows.map((tagRow) => tagRow.read<int>('tag_id')).toList(),
        'tagMatchMode': row.read<String>('tag_match_mode'),
        'status': row.read<String>('status_filter'),
        'minRating': row.read<int>('min_rating'),
        'includeDescendants': row.read<bool>('include_descendants'),
        'personId': row.readNullable<int>('person_filter_id'),
        'photoId': row.readNullable<int>('photo_filter_id'),
      };
      await createView(
        workspaceId: workspaceId,
        definition: BuiltInDatabases.bookmarks,
        name: row.read<String>('name'),
        layoutType: row.read<String>('layout_type'),
        filters: filters,
        sorts: [
          {
            'field': row.read<String>('sort_field'),
            'direction': row.read<String>('sort_direction'),
          }
        ],
        visibleProperties: _decodeCsv(row.read<String>('visible_properties')),
        propertyOrder: _decodeCsv(row.read<String>('visible_properties')),
      );
    }
  }
}
