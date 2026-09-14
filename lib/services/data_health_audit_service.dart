import '../data/database_view_health_audit.dart';
import '../data/object_health_audit.dart';
import '../data/relation_integrity_service.dart';
import '../repositories/object_search_health_audit.dart';
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
    this.viewId,
    this.databaseId,
  });

  final String subsystem;
  final String category;
  final int? objectId;
  final int? objectTypeId;
  final int? propertyId;
  final int? sourceObjectId;
  final int? targetObjectId;
  final int? viewId;
  final int? databaseId;
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

typedef ObjectHealthAuditRunner = Future<ObjectHealthAuditResult> Function();

/// Thin adapter over A's canonical read-only Object/value structural audit.
///
/// Object/value invariants remain owned by [ObjectHealthAudit]. Relation
/// payload semantics remain B-owned. This adapter only maps stable finding
/// kinds and safe internal Object/ObjectType/Property ids into the shared
/// data-health result model.
class ObjectDataHealthCheck implements DataHealthCheck {
  const ObjectDataHealthCheck({required ObjectHealthAuditRunner audit})
    : _audit = audit;

  factory ObjectDataHealthCheck.fromAudit({
    required ObjectHealthAudit audit,
    required int workspaceId,
  }) => ObjectDataHealthCheck(
    audit: () => audit.auditWorkspace(workspaceId),
  );

  final ObjectHealthAuditRunner _audit;

  @override
  String get checkId => 'object-integrity';

  @override
  String get subsystem => 'object';

  @override
  Future<List<DataHealthFinding>> run() async {
    final report = await _audit();
    return report.findings
        .map(
          (finding) => DataHealthFinding(
            subsystem: subsystem,
            category: finding.kind.name,
            objectId: finding.objectId,
            objectTypeId: finding.objectTypeId,
            propertyId: finding.propertyId,
          ),
        )
        .toList(growable: false);
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
  }) => FileDataHealthCheck(audit: () => audit.run(workspaceId: workspaceId));

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

typedef ObjectSearchHealthAuditRunner =
    Future<ObjectSearchHealthAuditResult> Function();

/// Thin adapter over E's canonical read-only Search health audit.
///
/// Search/FTS invariants remain owned by [ObjectSearchHealthAudit]. This adapter
/// only maps stable finding kinds and privacy-safe Object/ObjectType ids into
/// the shared data-health result model. Indexed text and raw persisted values
/// never cross this boundary.
class SearchDataHealthCheck implements DataHealthCheck {
  const SearchDataHealthCheck({required ObjectSearchHealthAuditRunner audit})
    : _audit = audit;

  factory SearchDataHealthCheck.fromAudit({
    required ObjectSearchHealthAudit audit,
    required int workspaceId,
  }) => SearchDataHealthCheck(audit: () => audit.auditWorkspace(workspaceId));

  final ObjectSearchHealthAuditRunner _audit;

  @override
  String get checkId => 'search-index-integrity';

  @override
  String get subsystem => 'search';

  @override
  Future<List<DataHealthFinding>> run() async {
    final report = await _audit();
    return report.findings
        .map(
          (finding) => DataHealthFinding(
            subsystem: subsystem,
            category: finding.kind.name,
            objectId: finding.objectId,
            objectTypeId:
                finding.canonicalObjectTypeId ?? finding.indexedObjectTypeId,
          ),
        )
        .toList(growable: false);
  }
}

typedef DatabaseViewHealthAuditRunner =
    Future<DatabaseViewHealthAuditResult> Function();

/// Thin adapter over C's canonical read-only Database/View health audit.
///
/// View parsing and persisted-reference semantics remain owned by
/// [DatabaseViewHealthAudit]. This adapter only maps stable issue kinds and safe
/// internal identifiers into the shared data-health result model. View names,
/// filter values, raw JSON and exception text never cross this boundary.
class DatabaseViewDataHealthCheck implements DataHealthCheck {
  const DatabaseViewDataHealthCheck({
    required DatabaseViewHealthAuditRunner audit,
  }) : _audit = audit;

  factory DatabaseViewDataHealthCheck.fromAudit({
    required DatabaseViewHealthAudit audit,
    required int workspaceId,
  }) => DatabaseViewDataHealthCheck(
    audit: () => audit.run(workspaceId: workspaceId),
  );

  final DatabaseViewHealthAuditRunner _audit;

  @override
  String get checkId => 'database-view-integrity';

  @override
  String get subsystem => 'database-view';

  @override
  Future<List<DataHealthFinding>> run() async {
    final report = await _audit();
    return report.findings
        .map(
          (finding) => DataHealthFinding(
            subsystem: subsystem,
            category: finding.kind.name,
            viewId: finding.viewId,
            databaseId: finding.databaseId,
            objectTypeId: finding.objectTypeId,
            propertyId: finding.propertyId,
          ),
        )
        .toList(growable: false);
  }
}
