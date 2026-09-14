import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/managed_file_ownership.dart';
import 'package:bookmark_app/services/canonical_file_health_audit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical File health audit is read-only and privacy-safe', () async {
    final root = await Directory.systemTemp.createTemp('file_health_');
    addTearDown(() => root.delete(recursive: true));

    final healthyFile = File('${root.path}/files/healthy.bin');
    final mismatchFile = File('${root.path}/files/mismatch.bin');
    final unsupportedFile = File('${root.path}/files/unsupported.bin');
    for (final file in <File>[healthyFile, mismatchFile, unsupportedFile]) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(const <int>[1, 2, 3]);
    }

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final service = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);

    final healthy = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: healthyFile.path,
      sizeBytes: 3,
      storageOwnership: ManagedFileOwnership.vaultManagedCopy,
    );
    final missing = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '${root.path}/files/missing.bin',
      sizeBytes: 3,
      storageOwnership: ManagedFileOwnership.vaultManagedCopy,
    );
    final mismatch = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: mismatchFile.path,
      sizeBytes: 99,
      storageOwnership: ManagedFileOwnership.vaultManagedCopy,
    );
    final unsupported = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: unsupportedFile.path,
      sizeBytes: 3,
    );
    await objectStore.setPropertyValue(
      objectId: unsupported.id,
      property: definition.storageOwnershipProperty,
      value: 'future-unknown-ownership',
    );

    final before = await objectStore.listObjects(definition.objectType.id);
    final result = await CanonicalFileHealthAudit(
      objectStore: objectStore,
      systemObjects: systemObjects,
      pathResolver: ProfilePathResolver(root.path),
    ).run(workspaceId: workspaceId);
    final after = await objectStore.listObjects(definition.objectType.id);

    expect(result.findings, hasLength(3));
    expect(result.affectedFileObjectIds, <int>{
      missing.id,
      mismatch.id,
      unsupported.id,
    });
    expect(
      result.findings
          .where((finding) => finding.fileObjectId == missing.id)
          .single
          .kind,
      CanonicalFileHealthIssueKind.missingBytes,
    );
    expect(
      result.findings
          .where((finding) => finding.fileObjectId == mismatch.id)
          .single
          .kind,
      CanonicalFileHealthIssueKind.persistedSizeMismatch,
    );
    expect(
      result.findings
          .where((finding) => finding.fileObjectId == unsupported.id)
          .single
          .kind,
      CanonicalFileHealthIssueKind.unsupportedOwnership,
    );
    expect(result.affectedFileObjectIds, isNot(contains(healthy.id)));
    expect(
      result.findings.map((finding) => finding.toString()).join(' '),
      isNot(contains(root.path)),
    );
    expect(
      after.map((object) => object.values).toList(),
      before.map((object) => object.values).toList(),
    );
  });
}
