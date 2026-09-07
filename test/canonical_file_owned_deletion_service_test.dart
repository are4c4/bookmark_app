import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/canonical_file_owned_deletion_service.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:bookmark_app/services/vault_managed_file_copy_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory vault;
  late Directory sources;
  late AppDatabase database;
  late ObjectStore objectStore;
  late SystemObjectStore systemObjects;
  late FileObjectService files;
  late FileObjectDefinition fileDefinition;
  late VaultManagedFileCopyService managedFiles;
  late CanonicalFileOwnedDeletionService deletion;
  late VaultManagedFileCopy copy;
  late int workspaceId;
  late int fileObjectId;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('owned_file_delete_vault_');
    sources = await Directory.systemTemp.createTemp('owned_file_delete_source_');
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: vault.path,
    );
    workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    files = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    fileDefinition = await files.ensureDefinition(workspaceId);
    managedFiles = VaultManagedFileCopyService();

    final source = File('${sources.path}/report.bin');
    await source.writeAsBytes(<int>[1, 2, 3, 4, 5]);
    copy = await managedFiles.copyIntoVault(
      sourcePath: source.path,
      vaultDirectoryPath: vault.path,
    );
    final fileObject = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: copy.storedPath,
      originalFilename: copy.originalFilename,
      sizeBytes: copy.sizeBytes,
      storageOwnership: copy.ownership.managedOwnership,
    );
    fileObjectId = fileObject.id;

    deletion = CanonicalFileOwnedDeletionService(
      database: database,
      objectStore: objectStore,
      resources: CanonicalFileManagedResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
        pathResolver: database.pathResolver,
      ),
      managedFiles: managedFiles,
    );
  });

  tearDown(() async {
    await database.close();
    await vault.delete(recursive: true);
    await sources.delete(recursive: true);
  });

  test('owned bytes delete only after the canonical File Object is gone',
      () async {
    final plan = await deletion.prepare(
      workspaceId: workspaceId,
      fileObjectTypeId: fileDefinition.objectType.id,
      fileObjectId: fileObjectId,
    );
    expect(plan, isNotNull);

    expect(
      await deletion.deletePreparedBytes(plan!),
      CanonicalFileOwnedDeleteResult.retainedObjectStillPresent,
    );
    expect(await File(copy.resolvedPath).exists(), isTrue);

    await objectStore.deleteObject(fileObjectId);

    expect(
      await deletion.deletePreparedBytes(plan),
      CanonicalFileOwnedDeleteResult.deleted,
    );
    expect(await File(copy.resolvedPath).exists(), isFalse);
  });

  test('custom Object File reference preserves owned bytes', () async {
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Paper',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: customTypeId,
      name: 'Attachment',
      type: ObjectPropertyType.file,
    );
    final customType = (await objectStore.getObjectType(customTypeId))!;
    final property = customType.properties.singleWhere(
      (candidate) => candidate.id == propertyId,
    );
    final customObjectId = await objectStore.createObject(
      objectTypeId: customTypeId,
      title: 'Shared paper',
    );
    await objectStore.setPropertyValue(
      objectId: customObjectId,
      property: property,
      value: copy.storedPath,
    );
    final plan = await deletion.prepare(
      workspaceId: workspaceId,
      fileObjectTypeId: fileDefinition.objectType.id,
      fileObjectId: fileObjectId,
    );

    await objectStore.deleteObject(fileObjectId);

    expect(
      await deletion.deletePreparedBytes(plan!),
      CanonicalFileOwnedDeleteResult.retainedSharedReference,
    );
    expect(await File(copy.resolvedPath).exists(), isTrue);

    await objectStore.deleteObject(customObjectId);
    expect(
      await deletion.deletePreparedBytes(plan),
      CanonicalFileOwnedDeleteResult.deleted,
    );
  });

  test('canonical Image sharing the same file preserves owned File bytes',
      () async {
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(GenericDatabaseStore(database)),
    );
    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: copy.storedPath,
      originalFilename: copy.originalFilename,
    );
    final plan = await deletion.prepare(
      workspaceId: workspaceId,
      fileObjectTypeId: fileDefinition.objectType.id,
      fileObjectId: fileObjectId,
    );

    await objectStore.deleteObject(fileObjectId);

    expect(
      await deletion.deletePreparedBytes(plan!),
      CanonicalFileOwnedDeleteResult.retainedSharedReference,
    );
    expect(await File(copy.resolvedPath).exists(), isTrue);

    await objectStore.deleteObject(image.id);
    expect(
      await deletion.deletePreparedBytes(plan),
      CanonicalFileOwnedDeleteResult.deleted,
    );
  });

  test('legacy Photo sharing the same file preserves owned File bytes',
      () async {
    await database.customStatement(
      'INSERT INTO photos(path, title) VALUES (?, ?)',
      <Object?>[copy.storedPath, 'Legacy shared photo'],
    );
    final plan = await deletion.prepare(
      workspaceId: workspaceId,
      fileObjectTypeId: fileDefinition.objectType.id,
      fileObjectId: fileObjectId,
    );

    await objectStore.deleteObject(fileObjectId);

    expect(
      await deletion.deletePreparedBytes(plan!),
      CanonicalFileOwnedDeleteResult.retainedSharedReference,
    );
    expect(await File(copy.resolvedPath).exists(), isTrue);
  });

  test('unowned File never produces a physical-delete plan', () async {
    final manual = File('${vault.path}/attachments/manual.bin');
    await manual.parent.create(recursive: true);
    await manual.writeAsBytes(<int>[9, 8, 7]);
    final object = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: manual.path,
    );

    final plan = await deletion.prepare(
      workspaceId: workspaceId,
      fileObjectTypeId: fileDefinition.objectType.id,
      fileObjectId: object.id,
    );

    expect(plan, isNull);
    await objectStore.deleteObject(object.id);
    expect(await manual.exists(), isTrue);
  });

  test('prepared deletion is idempotent when bytes disappear first', () async {
    final plan = await deletion.prepare(
      workspaceId: workspaceId,
      fileObjectTypeId: fileDefinition.objectType.id,
      fileObjectId: fileObjectId,
    );
    await objectStore.deleteObject(fileObjectId);
    await File(copy.resolvedPath).delete();

    expect(
      await deletion.deletePreparedBytes(plan!),
      CanonicalFileOwnedDeleteResult.alreadyMissing,
    );
  });
}
