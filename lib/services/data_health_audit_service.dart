import '../data/relation_integrity_service.dart';
import 'canonical_file_health_audit.dart';

/// Privacy-safe finding emitted by one read-only data-health check.
///
/// Findings deliberately contain stable categories and internal identifiers,
/// not raw persisted values, local paths, URLs, or exception strings.
class DataHealthFinding {
  const DataHealthFinding({
    required this.subsystem,
    required this.category,
    this.objectId,
    this.objectTypeId,
    this.propertyId,
    this.sourceObjectId,
    this.targetObjectId,
  });

  final String subsystem;
  final String category;
  final int? objectId;
  final int? objectTypeId;
  final int? propertyId;
  final int? sourceObjectId;
  final int? targetObjectId;
}

enum DataHealthCheckStatus { healthy, issues, failed }

class DataHealthCheckResult {
  const DataHealthCheckResult({
    required this.checkId,
    required this.subsystem,
    required this.status,
    required this.findings,
  });

  final String checkId;
  final String subsystem;
  final DataHealthCheckStatus status;
  final List<DataHealthFinding> findings;
}

class DataHealthReport {
  const DataHealthReport({required this.checks});

  final List<DataHealthCheckResult> checks;

  bool get isHealthy =>
      checks.every((check) => check.status == DataHealthCheckStatus.healthy);

  Iterable<DataHealthFinding> get findings =>
      checks.expand((check) => check.findings);
}

abstract interface class DataHealthCheck {
  String get checkId;
  String get subsystem;

  Future<List<DataHealthFinding>> run();
}

/// Runs independent read-only health checks in deterministic order.
///
/// A failing checker is represented as a stable `check-failed` finding and
/// never prevents later independent checks from running. The exception itself
/// is intentionally not copied into the report.
class DataHealthAuditService {
  DataHealthAuditService({required List<DataHealthCheck> checks})
    : _checks = List.unmodifiable(checks);

  final List<DataHealthCheck> _checks;

  Future<DataHealthReport> audit() async {
    final results = <DataHealthCheckResult>[];
    for (final check in _checks) {
      try {
        final findings = List<DataHealthFinding>.unmodifiable(
          await check.run(),
        );
        results.add(
          DataHealthCheckResult(
            checkId: check.checkId,
            subsystem: check.subsystem,
            status: findings.isEmpty
                ? DataHealthCheckStatus.healthy
                : DataHealthCheckStatus.issues,
            findings: findings,
          ),
        );
      } catch (_) {
        results.add(
          DataHealthCheckResult(
            checkId: check.checkId,
            subsystem: check.subsystem,
            status: DataHealthCheckStatus.failed,
            findings: [
              DataHealthFinding(
                subsystem: check.subsystem,
                category: 'check-failed',
              ),
            ],
          ),
        );
      }
    }
    return DataHealthReport(checks: List.unmodifiable(results));
  }
}

typedef RelationIntegrityAudit = Future<RelationIntegrityReport> Function();

/// Thin adapter over B's canonical read-only Relation integrity audit.
///
/// Relation invariants remain owned by [RelationIntegrityService]. This adapter
/// only maps its already-computed issue kinds and safe internal identifiers into
/// the shared data-health result model.
class RelationDataHealthCheck implements DataHealthCheck {
  const RelationDataHealthCheck({required RelationIntegrityAudit audit})
    : _audit = audit;

  factory RelationDataHealthCheck.fromService({
    required RelationIntegrityService service,
    required int workspaceId,
  }) =>
      RelationDataHealthCheck(audit: () => service.auditWorkspace(workspaceId));

  final RelationIntegrityAudit _audit;

  @override
  String get checkId => 'relation-integrity';

  @override
  String get subsystem => 'relation';

  @override
  Future<List<DataHealthFinding>> run() async {
    final report = await _audit();
    return report.issues
        .map(
          (issue) => DataHealthFinding(
            subsystem: subsystem,
            category: issue.kind.name,
            objectTypeId: issue.objectTypeId,
            propertyId: issue.propertyId,
            sourceObjectId: issue.sourceObjectId,
            targetObjectId: issue.targetObjectId,
          ),
        )
        .toList(growable: false);
  }
}

typedef CanonicalFileHealthAuditRunner =
    Future<CanonicalFileHealthAuditResult> Function();

/// Thin adapter over D's canonical read-only File health audit.
///
/// File persistence and filesystem invariants remain owned by
/// [CanonicalFileHealthAudit]. This adapter only maps its stable issue kinds and
/// safe internal File Object ids into the shared data-health result model.
class FileDataHealthCheck implements DataHealthCheck {
  const FileDataHealthCheck({required CanonicalFileHealthAuditRunner audit})
    : _audit = audit;

  factory FileDataHealthCheck.fromAudit({
    required CanonicalFileHealthAudit audit,
    required int workspaceId,
  }) => FileDataHealthCheck(
    audit: () => audit.run(workspaceId: workspaceId),
  );

  final CanonicalFileHealthAuditRunner _audit;

  @override
  String get checkId => 'file-integrity';

  @override
  String get subsystem => 'file';

  @override
  Future<List<DataHealthFinding>> run() async {
    final report = await _audit();
    return report.findings
        .map(
          (finding) => DataHealthFinding(
            subsystem: subsystem,
            category: finding.kind.name,
            objectId: finding.fileObjectId,
          ),
        )
        .toList(growable: false);
  }
}
