import 'package:bookmark_app/data/database_view_health_audit.dart';
import 'package:bookmark_app/data/object_health_audit.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/repositories/object_search_health_audit.dart';
import 'package:bookmark_app/services/canonical_file_health_audit.dart';
import 'package:bookmark_app/services/data_health_audit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregates healthy checks in deterministic order', () async {
    final calls = <String>[];
    final audit = DataHealthAuditService(
      checks: [
        _FakeCheck('object', calls: calls),
        _FakeCheck('view', calls: calls),
      ],
    );

    final report = await audit.audit();

    expect(calls, ['object', 'view']);
    expect(report.isHealthy, isTrue);
    expect(report.checks.map((check) => check.checkId), ['object', 'view']);
    expect(report.checks.map((check) => check.status), [
      DataHealthCheckStatus.healthy,
      DataHealthCheckStatus.healthy,
    ]);
    expect(report.findings, isEmpty);
  });

  test('continues after failure without exposing exception text', () async {
    final calls = <String>[];
    final audit = DataHealthAuditService(
      checks: [
        _FakeCheck(
          'broken',
          calls: calls,
          error: StateError('/Users/example/private-vault secret-token'),
        ),
        _FakeCheck(
          'later',
          calls: calls,
          findings: const [
            DataHealthFinding(subsystem: 'search', category: 'stale-index'),
          ],
        ),
      ],
    );

    final report = await audit.audit();

    expect(calls, ['broken', 'later']);
    expect(report.isHealthy, isFalse);
    expect(report.checks.first.status, DataHealthCheckStatus.failed);
    expect(report.checks.first.findings, hasLength(1));
    expect(report.checks.first.findings.single.category, 'check-failed');
    expect(report.checks.first.findings.single.subsystem, 'broken');
    expect(report.findings.map((finding) => finding.category), [
      'check-failed',
      'stale-index',
    ]);
    expect(report.findings.join(), isNot(contains('private-vault')));
    expect(report.findings.join(), isNot(contains('secret-token')));
  });

  test(
    'Object adapter maps canonical findings and privacy-safe ids only',
    () async {
      const canonicalFinding = ObjectHealthFinding(
        kind: ObjectHealthIssueKind.malformedValueJson,
        objectId: 1,
        objectTypeId: 2,
        propertyId: 3,
        propertyObjectTypeId: 4,
      );
      final check = ObjectDataHealthCheck(
        audit: () async =>
            const ObjectHealthAuditResult(findings: [canonicalFinding]),
      );

      final report = await DataHealthAuditService(checks: [check]).audit();

      expect(report.isHealthy, isFalse);
      expect(report.checks.single.checkId, 'object-integrity');
      expect(report.checks.single.status, DataHealthCheckStatus.issues);
      final finding = report.findings.single;
      expect(finding.subsystem, 'object');
      expect(finding.category, 'malformedValueJson');
      expect(finding.objectId, 1);
      expect(finding.objectTypeId, 2);
      expect(finding.propertyId, 3);
      expect(finding.sourceObjectId, isNull);
      expect(finding.targetObjectId, isNull);
      expect(finding.viewId, isNull);
      expect(finding.databaseId, isNull);
    },
  );

  test(
    'Relation adapter maps canonical issue kinds and safe ids only',
    () async {
      const issue = RelationIntegrityIssue(
        kind: RelationIntegrityIssueKind.missingTargetObject,
        message: 'raw persisted diagnostic text must not cross the adapter',
        objectTypeId: 11,
        propertyId: 12,
        sourceObjectId: 13,
        targetObjectId: 14,
      );
      final check = RelationDataHealthCheck(
        audit: () async => const RelationIntegrityReport(issues: [issue]),
      );

      final report = await DataHealthAuditService(checks: [check]).audit();

      expect(report.isHealthy, isFalse);
      expect(report.checks.single.status, DataHealthCheckStatus.issues);
      final finding = report.findings.single;
      expect(finding.subsystem, 'relation');
      expect(finding.category, 'missingTargetObject');
      expect(finding.objectTypeId, 11);
      expect(finding.propertyId, 12);
      expect(finding.sourceObjectId, 13);
      expect(finding.targetObjectId, 14);
      expect(
        finding.toString(),
        isNot(contains('raw persisted diagnostic text')),
      );
    },
  );

  test(
    'File adapter maps canonical findings and safe Object ids only',
    () async {
      const canonicalFinding = CanonicalFileHealthFinding(
        fileObjectId: 21,
        kind: CanonicalFileHealthIssueKind.missingBytes,
      );
      final check = FileDataHealthCheck(
        audit: () async =>
            const CanonicalFileHealthAuditResult(findings: [canonicalFinding]),
      );

      final report = await DataHealthAuditService(checks: [check]).audit();

      expect(report.isHealthy, isFalse);
      expect(report.checks.single.status, DataHealthCheckStatus.issues);
      final finding = report.findings.single;
      expect(finding.subsystem, 'file');
      expect(finding.category, 'missingBytes');
      expect(finding.objectId, 21);
      expect(finding.objectTypeId, isNull);
      expect(finding.propertyId, isNull);
      expect(finding.sourceObjectId, isNull);
      expect(finding.targetObjectId, isNull);
      expect(finding.toString(), isNot(contains('/')));
    },
  );

  test(
    'Search adapter maps canonical findings and privacy-safe ids only',
    () async {
      const canonicalFinding = ObjectSearchHealthFinding(
        kind: ObjectSearchHealthFindingKind.identityMismatch,
        objectId: 31,
        indexedObjectTypeId: 32,
        indexedWorkspaceId: 33,
        canonicalObjectTypeId: 34,
        canonicalWorkspaceId: 35,
      );
      final check = SearchDataHealthCheck(
        audit: () async => const ObjectSearchHealthAuditResult(
          workspaceId: 35,
          canonicalObjectCount: 1,
          inspectedIndexRowCount: 1,
          findings: [canonicalFinding],
        ),
      );

      final report = await DataHealthAuditService(checks: [check]).audit();

      expect(report.isHealthy, isFalse);
      expect(report.checks.single.checkId, 'search-index-integrity');
      expect(report.checks.single.status, DataHealthCheckStatus.issues);
      final finding = report.findings.single;
      expect(finding.subsystem, 'search');
      expect(finding.category, 'identityMismatch');
      expect(finding.objectId, 31);
      expect(finding.objectTypeId, 34);
      expect(finding.propertyId, isNull);
      expect(finding.sourceObjectId, isNull);
      expect(finding.targetObjectId, isNull);
    },
  );

  test(
    'Database/View adapter maps canonical findings and privacy-safe ids only',
    () async {
      const canonicalFinding = DatabaseViewHealthFinding(
        viewId: 41,
        kind: DatabaseViewHealthIssueKind.danglingFilterProperty,
        databaseId: 42,
        objectTypeId: 43,
        propertyId: 44,
      );
      final check = DatabaseViewDataHealthCheck(
        audit: () async =>
            const DatabaseViewHealthAuditResult(findings: [canonicalFinding]),
      );

      final report = await DataHealthAuditService(checks: [check]).audit();

      expect(report.isHealthy, isFalse);
      expect(report.checks.single.checkId, 'database-view-integrity');
      expect(report.checks.single.status, DataHealthCheckStatus.issues);
      final finding = report.findings.single;
      expect(finding.subsystem, 'database-view');
      expect(finding.category, 'danglingFilterProperty');
      expect(finding.viewId, 41);
      expect(finding.databaseId, 42);
      expect(finding.objectTypeId, 43);
      expect(finding.propertyId, 44);
      expect(finding.objectId, isNull);
      expect(finding.sourceObjectId, isNull);
      expect(finding.targetObjectId, isNull);
    },
  );
}

class _FakeCheck implements DataHealthCheck {
  _FakeCheck(
    this.checkId, {
    required this.calls,
    this.findings = const [],
    this.error,
  });

  @override
  final String checkId;
  final List<String> calls;
  final List<DataHealthFinding> findings;
  final Object? error;

  @override
  String get subsystem => checkId;

  @override
  Future<List<DataHealthFinding>> run() async {
    calls.add(checkId);
    final failure = error;
    if (failure != null) throw failure;
    return findings;
  }
}
