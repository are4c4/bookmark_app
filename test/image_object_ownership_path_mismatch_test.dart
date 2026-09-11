import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/managed_file_ownership.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'trusted ownership fails closed when source reuse points at another file',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final service = ImageObjectService(
        systemObjects: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );

      final existing = await service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/external/original.png',
        sourceUrl: 'https://cdn.example.com/preview.png',
      );
      final definition = await service.ensureDefinition(workspaceId);

      await expectLater(
        service.findOrCreateManaged(
          workspaceId: workspaceId,
          filePath: '/managed/new-copy.png',
          sourceUrl: 'https://cdn.example.com/preview.png',
          storageOwnership: ManagedFileOwnership.vaultManagedCopy,
        ),
        throwsStateError,
      );

      final objects = await objectStore.listObjects(definition.objectType.id);
      expect(objects, hasLength(1));
      final stored = objects.single;
      expect(stored.id, existing.id);
      expect(
        stored.values[definition.fileProperty.id],
        '/external/original.png',
      );
      expect(
        stored.values[definition.sourceUrlProperty.id],
        'https://cdn.example.com/preview.png',
      );
      expect(stored.values[definition.storageOwnershipProperty.id], isNull);
    },
  );
}
