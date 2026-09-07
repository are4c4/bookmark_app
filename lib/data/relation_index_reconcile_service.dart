import 'relation_index_service.dart';
import 'relation_integrity_service.dart';

class RelationIndexReconcileResult {
  const RelationIndexReconcileResult({
    required this.before,
    required this.after,
    required this.rebuilt,
  });

  final RelationIntegrityReport before;
  final RelationIntegrityReport after;
  final bool rebuilt;
}

/// Repairs only deterministic normalized-index drift.
///
/// Persisted Relation values remain the source of truth. If the integrity audit
/// finds any schema/value ambiguity, reconciliation fails before rebuilding so
/// callers cannot accidentally hide or normalize user-data inconsistencies.
class RelationIndexReconcileService {
  const RelationIndexReconcileService({
    required this.integrityService,
    required this.indexService,
  });

  final RelationIntegrityService integrityService;
  final RelationIndexService indexService;

  Future<RelationIndexReconcileResult> reconcileWorkspace(int workspaceId) async {
    final before = await integrityService.auditWorkspace(workspaceId);
    if (before.isHealthy) {
      return RelationIndexReconcileResult(
        before: before,
        after: before,
        rebuilt: false,
      );
    }

    final unsafeIssues = before.issues.where(
      (issue) => issue.kind != RelationIntegrityIssueKind.missingIndexEdge &&
          issue.kind != RelationIntegrityIssueKind.staleIndexEdge &&
          issue.kind != RelationIntegrityIssueKind.indexOrderMismatch,
    );
    if (unsafeIssues.isNotEmpty) {
      throw StateError(
        'Relation index reconciliation refused because the workspace has '
        'non-index integrity issues.',
      );
    }

    await indexService.rebuildWorkspace(workspaceId);
    var after = await integrityService.auditWorkspace(workspaceId);
    if (after.issues.isNotEmpty &&
        after.issues.every(
          (issue) => issue.kind == RelationIntegrityIssueKind.staleIndexEdge,
        )) {
      await _deleteRemainingStaleEdges(workspaceId);
      after = await integrityService.auditWorkspace(workspaceId);
    }
    if (!after.isHealthy) {
      throw StateError(
        'Relation index reconciliation did not restore a healthy workspace.',
      );
    }
    return RelationIndexReconcileResult(
      before: before,
      after: after,
      rebuilt: true,
    );
  }

  Future<void> _deleteRemainingStaleEdges(int workspaceId) async {
    final database = integrityService.bidirectionalStore.genericStore.database;
    await database.transaction(() async {
      final current = await integrityService.auditWorkspace(workspaceId);
      if (current.issues.any(
        (issue) => issue.kind != RelationIntegrityIssueKind.staleIndexEdge,
      )) {
        throw StateError(
          'Relation index reconciliation refused because integrity changed '
          'while removing stale edges.',
        );
      }
      for (final issue in current.issues) {
        final sourceObjectId = issue.sourceObjectId;
        final propertyId = issue.propertyId;
        final targetObjectId = issue.targetObjectId;
        if (sourceObjectId == null || propertyId == null || targetObjectId == null) {
          throw StateError(
            'Stale Relation edge diagnostics must identify the exact edge.',
          );
        }
        await database.customStatement(
          '''DELETE FROM object_relation_edges
             WHERE source_object_id = ?
               AND property_id = ?
               AND target_object_id = ?''',
          [sourceObjectId, propertyId, targetObjectId],
        );
      }
    });
  }
}
