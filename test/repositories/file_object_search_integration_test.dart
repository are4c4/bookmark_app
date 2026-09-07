import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/managed_file_ownership.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'canonical File search keeps user metadata without exposing internal identity',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final files = FileObjectService(
        systemObjects: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      final search = ObjectSearchRepository(genericStore);

      final file = await files.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: 'attachments/opaque-managed-path-token.pdf',
        title: 'Reference document',
        originalFilename: 'serre-number-theory-notes.pdf',
        contentType: 'application/pdf',
        sizeBytes: 424242,
        sha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        importedAt: DateTime.utc(2026, 9, 7),
        storageOwnership: ManagedFileOwnership.vaultManagedCopy,
      );

      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'serre'))
            .map((hit) => hit.objectId),
        contains(file.id),
      );
      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'application'))
            .map((hit) => hit.objectId),
        contains(file.id),
      );
      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'pdf'))
            .map((hit) => hit.objectId),
        contains(file.id),
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'opaque-managed-path-token',
        ),
        isEmpty,
        reason: 'managed File identity/path must not become free-text search data',
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: '0123456789abcdef',
        ),
        isEmpty,
        reason: 'SHA-256 is system-maintained identity metadata',
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'vault',
        ),
        isEmpty,
        reason: 'Storage ownership lifecycle keys must remain internal',
      );
    },
  );
}
