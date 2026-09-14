import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_search_health_audit.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore store;
  late ObjectStore objectStore;
  late ObjectSearchRepository search;
  late ObjectSearchHealthAudit audit;
  late int workspaceId;
  late int objectTypeId;
  late int objectId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = GenericDatabaseStore(database);
    objectStore = ObjectStore(store);
    search = ObjectSearchRepository(store);
    audit = ObjectSearchHealthAudit(store);
    workspaceId = await WorkspaceStore(database).initialize();
    objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Search health item',
    );
    objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Search health object',
    );
    await search.rebuildWorkspace(workspaceId);
  });

  tearDown(() => database.close());

  Future<void> insertIdentity({
    required Object objectId,
    required Object objectTypeId,
    required Object workspaceId,
  }) async {
    await database.customStatement(
      '''INSERT INTO object_search_fts(
           object_id,
           object_type_id,
           workspace_id,
           title,
           aliases,
           properties,
           body,
           relation_labels,
           weblink_metadata,
           derived_text
         ) VALUES (?, ?, ?, '', '', '', '', '', '', '')''',
      <Object>[objectId, objectTypeId, workspaceId],
    );
  }

  test('healthy canonical coverage reports no findings', () async {
    final result = await audit.auditWorkspace(workspaceId);

    expect(result.isHealthy, isTrue);
    expect(result.canonicalObjectCount, 1);
    expect(result.inspectedIndexRowCount, 1);
    expect(result.findings, isEmpty);
  });

  test('reports a missing canonical index identity without repairing it', () async {
    await database.customStatement(
      'DELETE FROM object_search_fts WHERE CAST(object_id AS INTEGER) = ?',
      <Object>[objectId],
    );

    final result = await audit.auditWorkspace(workspaceId);

    expect(
      result.findings.map((finding) => finding.kind),
      contains(ObjectSearchHealthFindingKind.missingIndexRow),
    );
    final rows = await database.customSelect(
      '''SELECT rowid FROM object_search_fts
         WHERE CAST(object_id AS INTEGER) = ?''',
      variables: <Variable<Object>>[Variable<int>(objectId)],
    ).get();
    expect(rows, isEmpty, reason: 'health audit must remain read-only');
  });

  test('reports stale, duplicate, and malformed index identities', () async {
    await insertIdentity(
      objectId: objectId,
      objectTypeId: objectTypeId,
      workspaceId: workspaceId,
    );
    await insertIdentity(
      objectId: 999999,
      objectTypeId: objectTypeId,
      workspaceId: workspaceId,
    );
    await insertIdentity(
      objectId: objectId,
      objectTypeId: 'broken-type',
      workspaceId: workspaceId,
    );

    final result = await audit.auditWorkspace(workspaceId);
    final kinds = result.findings.map((finding) => finding.kind).toSet();

    expect(kinds, contains(ObjectSearchHealthFindingKind.duplicateIndexRow));
    expect(kinds, contains(ObjectSearchHealthFindingKind.staleIndexRow));
    expect(kinds, contains(ObjectSearchHealthFindingKind.malformedIndexRow));
    final duplicate = result.findings.firstWhere(
      (finding) =>
          finding.kind == ObjectSearchHealthFindingKind.duplicateIndexRow,
    );
    expect(duplicate.objectId, objectId);
    expect(duplicate.rowCount, 2);
  });

  test('reports cross-workspace/type identity mismatch for canonical Object', () async {
    final secondWorkspaceId = await WorkspaceStore(database).createWorkspace(
      'Second workspace',
    );
    final secondTypeId = await objectStore.createObjectType(
      workspaceId: secondWorkspaceId,
      name: 'Other type',
    );
    await database.customStatement(
      'DELETE FROM object_search_fts WHERE CAST(object_id AS INTEGER) = ?',
      <Object>[objectId],
    );
    await insertIdentity(
      objectId: objectId,
      objectTypeId: secondTypeId,
      workspaceId: secondWorkspaceId,
    );

    final result = await audit.auditWorkspace(workspaceId);
    final mismatch = result.findings.firstWhere(
      (finding) =>
          finding.kind == ObjectSearchHealthFindingKind.identityMismatch,
    );

    expect(mismatch.objectId, objectId);
    expect(mismatch.indexedObjectTypeId, secondTypeId);
    expect(mismatch.indexedWorkspaceId, secondWorkspaceId);
    expect(mismatch.canonicalObjectTypeId, objectTypeId);
    expect(mismatch.canonicalWorkspaceId, workspaceId);
    expect(
      result.findings.map((finding) => finding.kind),
      contains(ObjectSearchHealthFindingKind.missingIndexRow),
    );
  });
}
