import 'dart:convert';

import 'package:drift/drift.dart';

import 'generic_database_store.dart';

enum ObjectHealthIssueKind {
  crossObjectTypeValue,
  computedPropertyHasStoredValue,
  malformedValueJson,
}

class ObjectHealthFinding {
  const ObjectHealthFinding({
    required this.kind,
    required this.objectId,
    required this.objectTypeId,
    required this.propertyId,
    required this.propertyObjectTypeId,
  });

  final ObjectHealthIssueKind kind;
  final int objectId;
  final int objectTypeId;
  final int propertyId;
  final int propertyObjectTypeId;
}

class ObjectHealthAuditResult {
  const ObjectHealthAuditResult({required this.findings});

  final List<ObjectHealthFinding> findings;

  bool get isHealthy => findings.isEmpty;
  int get issueCount => findings.length;

  Iterable<ObjectHealthFinding> issuesOf(ObjectHealthIssueKind kind) =>
      findings.where((finding) => finding.kind == kind);

  Set<int> get affectedObjectIds =>
      findings.map((finding) => finding.objectId).toSet();
}

/// Read-only structural audit for A-owned generic Object/value persistence.
///
/// This deliberately excludes Relation payload semantics. B's canonical
/// Relation integrity audit remains authoritative for target, cardinality,
/// ordering, backlink/index and Relation-payload correctness.
class ObjectHealthAudit {
  ObjectHealthAudit(this._store);

  final GenericDatabaseStore _store;

  Future<ObjectHealthAuditResult> auditWorkspace(int workspaceId) async {
    if (workspaceId <= 0) return _emptyResult;

    await _store.ensureSchema();
    final rows = await _store.database
        .customSelect(
          '''SELECT v.record_id,
                r.database_id AS object_type_id,
                v.property_id,
                p.database_id AS property_object_type_id,
                p.type AS property_type,
                v.value_json
         FROM generic_values v
         JOIN generic_records r ON r.id = v.record_id
         JOIN generic_databases d ON d.id = r.database_id
         JOIN generic_properties p ON p.id = v.property_id
         WHERE d.workspace_id = ?
         ORDER BY v.record_id, v.property_id''',
          variables: <Variable>[Variable<int>(workspaceId)],
        )
        .get();

    final findings = <ObjectHealthFinding>[];
    for (final row in rows) {
      final objectId = row.read<int>('record_id');
      final objectTypeId = row.read<int>('object_type_id');
      final propertyId = row.read<int>('property_id');
      final propertyObjectTypeId = row.read<int>('property_object_type_id');
      final propertyType = row.read<String>('property_type');

      if (objectTypeId != propertyObjectTypeId) {
        findings.add(
          ObjectHealthFinding(
            kind: ObjectHealthIssueKind.crossObjectTypeValue,
            objectId: objectId,
            objectTypeId: objectTypeId,
            propertyId: propertyId,
            propertyObjectTypeId: propertyObjectTypeId,
          ),
        );
        continue;
      }

      if (propertyType == 'formula' || propertyType == 'rollup') {
        findings.add(
          ObjectHealthFinding(
            kind: ObjectHealthIssueKind.computedPropertyHasStoredValue,
            objectId: objectId,
            objectTypeId: objectTypeId,
            propertyId: propertyId,
            propertyObjectTypeId: propertyObjectTypeId,
          ),
        );
        continue;
      }

      if (propertyType == 'relation') {
        continue;
      }

      try {
        jsonDecode(row.read<String>('value_json'));
      } on FormatException {
        findings.add(
          ObjectHealthFinding(
            kind: ObjectHealthIssueKind.malformedValueJson,
            objectId: objectId,
            objectTypeId: objectTypeId,
            propertyId: propertyId,
            propertyObjectTypeId: propertyObjectTypeId,
          ),
        );
      }
    }

    return ObjectHealthAuditResult(
      findings: List<ObjectHealthFinding>.unmodifiable(findings),
    );
  }

  static const _emptyResult = ObjectHealthAuditResult(
    findings: <ObjectHealthFinding>[],
  );
}
