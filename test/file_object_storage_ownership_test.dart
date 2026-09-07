import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/managed_file_ownership.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical File persists only typed managed storage ownership', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: ObjectStore(genericStore),
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);

    final owned = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/owned.bin',
      storageOwnership: ManagedFileOwnership.vaultManagedCopy,
    );
    final unowned = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/external/reference.bin',
    );

    expect(
      owned.values[definition.storageOwnershipProperty.id],
      ManagedFileOwnership.vaultManagedCopy.storageKey,
    );
    expect(
      unowned.values[definition.storageOwnershipProperty.id],
      isNull,
    );
    expect(definition.storageOwnershipProperty.config['system'], isTrue);
  });

  test('same-path retry backfills missing ownership without changing identity',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);

    final first = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/retry.bin',
    );
    final backfilled = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/retry.bin',
      storageOwnership: ManagedFileOwnership.vaultManagedCopy,
    );

    expect(backfilled.id, first.id);
    expect(
      backfilled.values[definition.storageOwnershipProperty.id],
      ManagedFileOwnership.vaultManagedCopy.storageKey,
    );
    expect(await objectStore.listObjects(definition.objectType.id), hasLength(1));
  });

  test('unknown persisted ownership does not become a recognized grant', () {
    expect(ManagedFileOwnership.fromStorageKey('unknown-owner'), isNull);
    expect(
      ManagedFileOwnership.fromStorageKey(
        ManagedFileOwnership.vaultManagedCopy.storageKey,
      ),
      ManagedFileOwnership.vaultManagedCopy,
    );
  });
}
