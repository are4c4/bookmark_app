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
          issue.kind != RelationIntegrityIssueKind.staleIndexEdge,
    );
    if (unsafeIssues.isNotEmpty) {
      throw StateError(
        'Relation index reconciliation refused because the workspace has '
        'non-index integrity issues.',
      );
    }

    await indexService.rebuildWorkspace(workspaceId);
    final after = await integrityService.auditWorkspace(workspaceId);
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
}
