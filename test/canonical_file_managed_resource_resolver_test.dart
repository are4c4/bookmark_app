import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/managed_file_ownership.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/file_managed_resource_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical resolver activates only for the system File ObjectType',
      () async {
    final root = await Directory.systemTemp.createTemp('canonical_file_resource_');
    addTearDown(() => root.delete(recursive: true));
    final managed = File('${root.path}/attachments/report.pdf');
    await managed.parent.create(recursive: true);
    await managed.writeAsBytes('%PDF-1.7\n'.codeUnits);

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
    final files = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final fileDefinition = await files.ensureDefinition(workspaceId);
    final canonicalFile = await files.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      contentType: 'application/pdf',
      storageOwnership: ManagedFileOwnership.vaultManagedCopy,
    );

    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Document reference',
    );
    final customFilePropertyId = await objectStore.createProperty(
      objectTypeId: customTypeId,
      name: 'File',
      type: ObjectPropertyType.file,
    );
    final customType = (await objectStore.getObjectType(customTypeId))!;
    final customFileProperty = customType.properties.singleWhere(
      (property) => property.id == customFilePropertyId,
    );
    final customObjectId = await objectStore.createObject(
      objectTypeId: customTypeId,
      title: 'Not a built-in File',
    );
    await objectStore.setPropertyValue(
      objectId: customObjectId,
      property: customFileProperty,
      value: database.pathResolver.toStoredPath(managed.path),
    );

    final resolver = CanonicalFileManagedResourceResolver(
      objectStore: objectStore,
      systemObjects: systemObjects,
      pathResolver: database.pathResolver,
    );

    final canonical = await resolver.resolveManaged(
      fileObjectTypeId: fileDefinition.objectType.id,
      fileObjectId: canonicalFile.id,
    );
    final custom = await resolver.resolveManaged(
      fileObjectTypeId: customTypeId,
      fileObjectId: customObjectId,
    );

    expect(canonical, isNotNull);
    expect(canonical?.fileObjectId, canonicalFile.id);
    expect(canonical?.storedPath, 'attachments/report.pdf');
    expect(canonical?.filePath, managed.path);
    expect(
      canonical?.storageOwnership,
      ManagedFileOwnership.vaultManagedCopy,
    );
    expect(custom, isNull);
  });
}
