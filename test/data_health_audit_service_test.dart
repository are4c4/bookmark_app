import 'package:bookmark_app/data/relation_integrity_service.dart';
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
    expect(
      report.checks.map((check) => check.checkId),
      ['object', 'view'],
    );
    expect(
      report.checks.map((check) => check.status),
      [DataHealthCheckStatus.healthy, DataHealthCheckStatus.healthy],
    );
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
    expect(
      report.findings.map((finding) => finding.category),
      ['check-failed', 'stale-index'],
    );
    expect(report.findings.join(), isNot(contains('private-vault')));
    expect(report.findings.join(), isNot(contains('secret-token')));
  });

  test('Relation adapter maps canonical issue kinds and safe ids only', () async {
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
    expect(finding.toString(), isNot(contains('raw persisted diagnostic text')));
  });
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
    if (error case final error?) throw error;
    return findings;
  }
}
