import '../data/app_database.dart';
import '../data/generic_database_store.dart';

/// Stable, privacy-safe categories reported by the canonical Search health
/// audit. Findings intentionally contain identity metadata only, never indexed
/// user text.
enum ObjectSearchHealthFindingKind {
  indexUnavailable,
  missingIndexRow,
  staleIndexRow,
  duplicateIndexRow,
  identityMismatch,
  titleMismatch,
  malformedIndexRow,
}

class ObjectSearchHealthFinding {
  const ObjectSearchHealthFinding({
    required this.kind,
    this.objectId,
    this.indexedObjectTypeId,
    this.indexedWorkspaceId,
    this.canonicalObjectTypeId,
    this.canonicalWorkspaceId,
    this.rowCount = 1,
  });

  final ObjectSearchHealthFindingKind kind;
  final int? objectId;
  final int? indexedObjectTypeId;
  final int? indexedWorkspaceId;
  final int? canonicalObjectTypeId;
  final int? canonicalWorkspaceId;
  final int rowCount;
}

class ObjectSearchHealthAuditResult {
  const ObjectSearchHealthAuditResult({
    required this.workspaceId,
    required this.canonicalObjectCount,
    required this.inspectedIndexRowCount,
    required this.findings,
  });

  final int workspaceId;
  final int canonicalObjectCount;
  final int inspectedIndexRowCount;
  final List<ObjectSearchHealthFinding> findings;

  bool get isHealthy => findings.isEmpty;
}

class _CanonicalSearchIdentity {
  const _CanonicalSearchIdentity({
    required this.objectId,
    required this.objectTypeId,
    required this.workspaceId,
    required this.title,
  });

  final int objectId;
  final int objectTypeId;
  final int workspaceId;
  final String title;
}

class _IndexedSearchIdentity {
  const _IndexedSearchIdentity({
    required this.objectId,
    required this.objectTypeId,
    required this.workspaceId,
    required this.title,
  });

  final int? objectId;
  final int? objectTypeId;
  final int? workspaceId;
  final String? title;
}

/// Read-only checker for the canonical `object_search_fts` identity projection.
///
/// This boundary never rebuilds, refreshes, deletes, inserts, or repairs Search
/// state. It compares stable Object/ObjectType/workspace identities plus
/// equality of the canonical title bucket. Findings expose identity metadata
/// only, never title text, Body, Properties, URLs, or other user content.
class ObjectSearchHealthAudit {
  ObjectSearchHealthAudit(GenericDatabaseStore genericStore)
    : _database = genericStore.database;

  final AppDatabase _database;

  Future<bool> _indexExists() async {
    final rows = await _database.customSelect('''SELECT 1 AS present
         FROM sqlite_master
         WHERE type = 'table' AND name = 'object_search_fts'
         LIMIT 1''').get();
    return rows.isNotEmpty;
  }

  int? _parseIdentity(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<List<_CanonicalSearchIdentity>> _canonicalIdentities() async {
    final rows = await _database.customSelect('''SELECT
           r.id AS object_id,
           r.database_id AS object_type_id,
           d.workspace_id AS workspace_id,
           r.title AS title
         FROM generic_records r
         JOIN generic_databases d ON d.id = r.database_id
         ORDER BY r.id''').get();
    return rows
        .map(
          (row) => _CanonicalSearchIdentity(
            objectId: row.read<int>('object_id'),
            objectTypeId: row.read<int>('object_type_id'),
            workspaceId: row.read<int>('workspace_id'),
            title: row.read<String>('title'),
          ),
        )
        .toList(growable: false);
  }

  Future<List<_IndexedSearchIdentity>> _indexedIdentities() async {
    final rows = await _database.customSelect('''SELECT
           CAST(object_id AS TEXT) AS object_id_raw,
           CAST(object_type_id AS TEXT) AS object_type_id_raw,
           CAST(workspace_id AS TEXT) AS workspace_id_raw,
           CAST(title AS TEXT) AS title_raw
         FROM object_search_fts
         ORDER BY rowid''').get();
    return rows
        .map(
          (row) => _IndexedSearchIdentity(
            objectId: _parseIdentity(row.readNullable<String>('object_id_raw')),
            objectTypeId: _parseIdentity(
              row.readNullable<String>('object_type_id_raw'),
            ),
            workspaceId: _parseIdentity(
              row.readNullable<String>('workspace_id_raw'),
            ),
            title: row.readNullable<String>('title_raw'),
          ),
        )
        .toList(growable: false);
  }

  Future<ObjectSearchHealthAuditResult> auditWorkspace(int workspaceId) async {
    final canonical = await _canonicalIdentities();
    final canonicalById = <int, _CanonicalSearchIdentity>{
      for (final identity in canonical) identity.objectId: identity,
    };
    final targetCanonical = canonical
        .where((identity) => identity.workspaceId == workspaceId)
        .toList(growable: false);

    if (!await _indexExists()) {
      return ObjectSearchHealthAuditResult(
        workspaceId: workspaceId,
        canonicalObjectCount: targetCanonical.length,
        inspectedIndexRowCount: 0,
        findings: const <ObjectSearchHealthFinding>[
          ObjectSearchHealthFinding(
            kind: ObjectSearchHealthFindingKind.indexUnavailable,
          ),
        ],
      );
    }

    final indexed = await _indexedIdentities();
    final relevant = indexed
        .where((identity) {
          if (identity.workspaceId == workspaceId) return true;
          final objectId = identity.objectId;
          if (objectId == null) return false;
          return canonicalById[objectId]?.workspaceId == workspaceId;
        })
        .toList(growable: false);

    final findings = <ObjectSearchHealthFinding>[];
    final rowsByObjectId = <int, List<_IndexedSearchIdentity>>{};
    final exactRowsByObjectId = <int, int>{};

    for (final indexedIdentity in relevant) {
      final objectId = indexedIdentity.objectId;
      final objectTypeId = indexedIdentity.objectTypeId;
      final indexedWorkspaceId = indexedIdentity.workspaceId;
      if (objectId == null ||
          objectTypeId == null ||
          indexedWorkspaceId == null) {
        findings.add(
          ObjectSearchHealthFinding(
            kind: ObjectSearchHealthFindingKind.malformedIndexRow,
            objectId: objectId,
            indexedObjectTypeId: objectTypeId,
            indexedWorkspaceId: indexedWorkspaceId,
          ),
        );
        continue;
      }

      rowsByObjectId
          .putIfAbsent(objectId, () => <_IndexedSearchIdentity>[])
          .add(indexedIdentity);
      final canonicalIdentity = canonicalById[objectId];
      if (canonicalIdentity == null) {
        if (indexedWorkspaceId == workspaceId) {
          findings.add(
            ObjectSearchHealthFinding(
              kind: ObjectSearchHealthFindingKind.staleIndexRow,
              objectId: objectId,
              indexedObjectTypeId: objectTypeId,
              indexedWorkspaceId: indexedWorkspaceId,
            ),
          );
        }
        continue;
      }

      final exact =
          canonicalIdentity.objectTypeId == objectTypeId &&
          canonicalIdentity.workspaceId == indexedWorkspaceId;
      if (exact) {
        exactRowsByObjectId[objectId] =
            (exactRowsByObjectId[objectId] ?? 0) + 1;
        if (indexedIdentity.title != canonicalIdentity.title) {
          findings.add(
            ObjectSearchHealthFinding(
              kind: ObjectSearchHealthFindingKind.titleMismatch,
              objectId: objectId,
              indexedObjectTypeId: objectTypeId,
              indexedWorkspaceId: indexedWorkspaceId,
              canonicalObjectTypeId: canonicalIdentity.objectTypeId,
              canonicalWorkspaceId: canonicalIdentity.workspaceId,
            ),
          );
        }
        continue;
      }

      findings.add(
        ObjectSearchHealthFinding(
          kind: ObjectSearchHealthFindingKind.identityMismatch,
          objectId: objectId,
          indexedObjectTypeId: objectTypeId,
          indexedWorkspaceId: indexedWorkspaceId,
          canonicalObjectTypeId: canonicalIdentity.objectTypeId,
          canonicalWorkspaceId: canonicalIdentity.workspaceId,
        ),
      );
    }

    for (final entry in rowsByObjectId.entries) {
      if (entry.value.length <= 1) continue;
      final canonicalIdentity = canonicalById[entry.key];
      findings.add(
        ObjectSearchHealthFinding(
          kind: ObjectSearchHealthFindingKind.duplicateIndexRow,
          objectId: entry.key,
          canonicalObjectTypeId: canonicalIdentity?.objectTypeId,
          canonicalWorkspaceId: canonicalIdentity?.workspaceId,
          rowCount: entry.value.length,
        ),
      );
    }

    for (final canonicalIdentity in targetCanonical) {
      if ((exactRowsByObjectId[canonicalIdentity.objectId] ?? 0) > 0) continue;
      findings.add(
        ObjectSearchHealthFinding(
          kind: ObjectSearchHealthFindingKind.missingIndexRow,
          objectId: canonicalIdentity.objectId,
          canonicalObjectTypeId: canonicalIdentity.objectTypeId,
          canonicalWorkspaceId: canonicalIdentity.workspaceId,
        ),
      );
    }

    findings.sort((left, right) {
      final kindOrder = left.kind.index.compareTo(right.kind.index);
      if (kindOrder != 0) return kindOrder;
      return (left.objectId ?? -1).compareTo(right.objectId ?? -1);
    });

    return ObjectSearchHealthAuditResult(
      workspaceId: workspaceId,
      canonicalObjectCount: targetCanonical.length,
      inspectedIndexRowCount: relevant.length,
      findings: List<ObjectSearchHealthFinding>.unmodifiable(findings),
    );
  }
}
