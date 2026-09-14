import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_group.dart';
import '../domain/object_query.dart';
import 'database_collection_store.dart';
import 'database_view_gallery_adapter.dart';
import 'database_view_group_adapter.dart';
import 'database_view_query_adapter.dart';
import 'database_view_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';

enum DatabaseViewHealthIssueKind {
  malformedFilters,
  malformedSorts,
  malformedSettings,
  danglingVisibleProperty,
  danglingPropertyOrder,
  danglingFilterProperty,
  danglingSortProperty,
  danglingGroupProperty,
  danglingGalleryCoverProperty,
}

class DatabaseViewHealthFinding {
  const DatabaseViewHealthFinding({
    required this.viewId,
    required this.kind,
    this.databaseId,
    this.objectTypeId,
    this.propertyId,
  });

  final int viewId;
  final DatabaseViewHealthIssueKind kind;
  final int? databaseId;
  final int? objectTypeId;
  final int? propertyId;
}

class DatabaseViewHealthAuditResult {
  const DatabaseViewHealthAuditResult({required this.findings});

  final List<DatabaseViewHealthFinding> findings;

  int get issueCount => findings.length;

  Set<int> get affectedViewIds =>
      findings.map((finding) => finding.viewId).toSet();
}

/// Privacy-safe, read-only health audit for persisted Database View config.
///
/// The audit reuses the canonical View adapters for reference semantics and
/// reports only stable issue kinds plus internal ids. It never repairs View
/// configuration or exposes names, filter values, raw JSON, or exception text.
class DatabaseViewHealthAudit {
  DatabaseViewHealthAudit({
    required GenericDatabaseStore genericStore,
    required ObjectStore objectStore,
    required DatabaseViewStore viewStore,
  }) : _genericStore = genericStore,
       _objectStore = objectStore,
       _viewStore = viewStore,
       _collectionStore = DatabaseCollectionStore(
         genericStore: genericStore,
         objectStore: objectStore,
       );

  final GenericDatabaseStore _genericStore;
  final ObjectStore _objectStore;
  final DatabaseViewStore _viewStore;
  final DatabaseCollectionStore _collectionStore;

  static const _queryAdapter = DatabaseViewQueryAdapter();
  static const _groupAdapter = DatabaseViewGroupAdapter();
  static const _galleryAdapter = DatabaseViewGalleryAdapter();

  Future<DatabaseViewHealthAuditResult> run({required int workspaceId}) async {
    if (workspaceId <= 0) return _emptyResult;

    final views = await _viewStore.listWorkspaceViews(workspaceId: workspaceId);
    final rawRows = await _genericStore.database
        .customSelect(
          '''SELECT id, filters_json, sorts_json, settings_json
         FROM database_views
         WHERE workspace_id = ?''',
          variables: [Variable<int>(workspaceId)],
        )
        .get();
    final rawById = <int, QueryRow>{
      for (final row in rawRows) row.read<int>('id'): row,
    };

    final findings = <DatabaseViewHealthFinding>[];
    for (final view in views) {
      final row = rawById[view.id];
      if (row != null) {
        _appendMalformedFindings(findings, view.id, row);
      }
      await _appendReferenceFindings(findings, view);
    }

    return DatabaseViewHealthAuditResult(
      findings: List<DatabaseViewHealthFinding>.unmodifiable(findings),
    );
  }

  static const _emptyResult = DatabaseViewHealthAuditResult(
    findings: <DatabaseViewHealthFinding>[],
  );

  void _appendMalformedFindings(
    List<DatabaseViewHealthFinding> findings,
    int viewId,
    QueryRow row,
  ) {
    final filters = _decodeMap(row.read<String>('filters_json'));
    if (filters == null || !_validFilterRules(filters)) {
      findings.add(
        DatabaseViewHealthFinding(
          viewId: viewId,
          kind: DatabaseViewHealthIssueKind.malformedFilters,
        ),
      );
    }

    final sorts = _decodeList(row.read<String>('sorts_json'));
    if (sorts == null ||
        sorts.any((item) => ObjectSortRule.fromJson(item) == null)) {
      findings.add(
        DatabaseViewHealthFinding(
          viewId: viewId,
          kind: DatabaseViewHealthIssueKind.malformedSorts,
        ),
      );
    }

    final settings = _decodeMap(row.read<String>('settings_json'));
    if (settings == null || !_validSettings(settings)) {
      findings.add(
        DatabaseViewHealthFinding(
          viewId: viewId,
          kind: DatabaseViewHealthIssueKind.malformedSettings,
        ),
      );
    }
  }

  Future<void> _appendReferenceFindings(
    List<DatabaseViewHealthFinding> findings,
    DatabaseViewConfig view,
  ) async {
    final databaseId = _customDatabaseId(view.databaseKey);
    if (databaseId == null) return;

    try {
      final collection = await _collectionStore.readEffective(databaseId);
      if (collection == null || collection.workspaceId != view.workspaceId)
        return;
      final type = await _objectStore.getObjectType(
        collection.targetObjectTypeId,
      );
      if (type == null || type.workspaceId != view.workspaceId) return;
      final validPropertyIds = type.properties
          .map((property) => property.id)
          .toSet();

      void append(DatabaseViewHealthIssueKind kind, int propertyId) {
        if (validPropertyIds.contains(propertyId)) return;
        findings.add(
          DatabaseViewHealthFinding(
            viewId: view.id,
            kind: kind,
            databaseId: databaseId,
            objectTypeId: type.id,
            propertyId: propertyId,
          ),
        );
      }

      for (final key in view.visibleProperties) {
        final propertyId = _propertyIdFromKey(key);
        if (propertyId != null) {
          append(
            DatabaseViewHealthIssueKind.danglingVisibleProperty,
            propertyId,
          );
        }
      }
      for (final key in view.propertyOrder) {
        final propertyId = _propertyIdFromKey(key);
        if (propertyId != null) {
          append(DatabaseViewHealthIssueKind.danglingPropertyOrder, propertyId);
        }
      }

      final query = _queryAdapter.decode(view);
      for (final rule in query.filters) {
        final propertyId = rule.propertyId;
        if (propertyId != null) {
          append(
            DatabaseViewHealthIssueKind.danglingFilterProperty,
            propertyId,
          );
        }
      }
      for (final rule in query.sorts) {
        final propertyId = rule.propertyId;
        if (propertyId != null) {
          append(DatabaseViewHealthIssueKind.danglingSortProperty, propertyId);
        }
      }

      final groupPropertyId = _groupAdapter.decode(view)?.propertyId;
      if (groupPropertyId != null) {
        append(
          DatabaseViewHealthIssueKind.danglingGroupProperty,
          groupPropertyId,
        );
      }
      final cover = _galleryAdapter.decodeCoverSource(view);
      final coverPropertyId = cover.relationPropertyId;
      if (cover.isRelation && coverPropertyId != null) {
        append(
          DatabaseViewHealthIssueKind.danglingGalleryCoverProperty,
          coverPropertyId,
        );
      }
    } catch (_) {
      // A corrupt Database collection context is audited by its owning boundary.
      // Keep independent Views auditable instead of turning one failure into a
      // workspace-wide exception or duplicating collection-health semantics.
    }
  }

  bool _validFilterRules(Map<String, dynamic> filters) {
    final rawRules = filters['propertyRules'];
    if (rawRules == null) return true;
    if (rawRules is! List) return false;
    return rawRules.every((item) => ObjectFilterRule.fromJson(item) != null);
  }

  bool _validSettings(Map<String, dynamic> settings) {
    final rawGroup = settings[DatabaseViewGroupAdapter.groupSettingsKey];
    if (rawGroup != null && ObjectGroupRule.fromJson(rawGroup) == null) {
      return false;
    }
    final rawCover =
        settings[DatabaseViewGalleryAdapter.coverSourceSettingsKey];
    if (rawCover == null) return true;
    if (rawCover is! Map) return false;
    final kind = GalleryCoverSourceKind.fromStorage(rawCover['kind']);
    if (kind == null) return false;
    if (kind == GalleryCoverSourceKind.imageRelation ||
        kind == GalleryCoverSourceKind.weblinkRelationRepresentativeImage) {
      final rawId = rawCover['relationPropertyId'];
      final id = rawId is int ? rawId : int.tryParse('$rawId');
      return id != null && id > 0;
    }
    return true;
  }

  Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  List<dynamic>? _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  int? _customDatabaseId(String key) {
    const prefix = 'custom:';
    if (!key.startsWith(prefix)) return null;
    final id = int.tryParse(key.substring(prefix.length));
    return id != null && id > 0 ? id : null;
  }

  int? _propertyIdFromKey(String key) {
    if (!key.startsWith('p:')) return null;
    final id = int.tryParse(key.substring(2));
    return id != null && id > 0 ? id : null;
  }
}
