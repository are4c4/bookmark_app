import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/services/person_profile_image_relation_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Object sync promotes legacy Person profile Photo after Photo to Image mapping exists',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();

      await database.customStatement(
        "INSERT INTO photos(path, title) VALUES ('photos/sync-profile.jpg', 'Sync profile')",
      );
      final photoId = (await database.customSelect(
        "SELECT id FROM photos WHERE path = 'photos/sync-profile.jpg'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        '''INSERT INTO people(name, profile_photo_id)
           VALUES ('Sync Profile Person', ?)''',
        <Object>[photoId],
      );
      final personId = (await database.customSelect(
        "SELECT id FROM people WHERE name = 'Sync Profile Person'",
      ).getSingle())
          .read<int>('id');

      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);
      await sync.syncWorkspace(workspaceId);

      final state = await PersonProfileImageRelationService(database).load(
        workspaceId: workspaceId,
        personId: personId,
      );
      expect(state.selectedImageObjectId, isNotNull);
      expect(state.legacyProfilePhotoId, photoId);
      expect(state.property.allowsMultipleRelations, isFalse);

      final personType = (await SystemObjectStore(
        database: database,
        objectStore: sync.objectStore,
      ).getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: PersonObjectBridge.systemKey,
      ))!;
      expect(
        personType.properties.where(
          (property) =>
              property.name ==
              PersonProfileImageRelationService.profileImagePropertyName,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'Object sync leaves an unmapped legacy profile Photo retryable without inventing an Image',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();

      await database.customStatement(
        "INSERT INTO photos(path, title) VALUES ('photos/retry-profile.jpg', 'Retry profile')",
      );
      final photoId = (await database.customSelect(
        "SELECT id FROM photos WHERE path = 'photos/retry-profile.jpg'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        '''INSERT INTO people(name, profile_photo_id)
           VALUES ('Retry Profile Person', ?)''',
        <Object>[photoId],
      );
      final personId = (await database.customSelect(
        "SELECT id FROM people WHERE name = 'Retry Profile Person'",
      ).getSingle())
          .read<int>('id');

      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);
      await sync.syncWorkspace(workspaceId);

      final mapping = await database.customSelect(
        'SELECT object_id FROM photo_object_links WHERE photo_id = ?',
        variables: [driftVariableInt(photoId)],
      ).getSingleOrNull();
      expect(mapping, isNotNull);

      // Simulate a temporarily unavailable compatibility mapping after the Photo
      // promotion pass. Workspace migration must skip rather than manufacture a
      // second identity, and a later sync can restore it through CoreObjectBridge.
      await database.customStatement(
        'DELETE FROM photo_object_links WHERE photo_id = ?',
        <Object>[photoId],
      );
      await database.customStatement(
        '''UPDATE generic_values SET value_json = '[]'
           WHERE record_id = ? AND property_id = ?''',
        <Object>[
          (await PersonProfileImageRelationService(database).load(
            workspaceId: workspaceId,
            personId: personId,
          ))
              .personObjectId,
          (await PersonProfileImageRelationService(database).load(
            workspaceId: workspaceId,
            personId: personId,
          ))
              .property
              .id,
        ],
      );

      // The production migration itself is retry-safe when no mapping exists.
      await PersonProfileImageRelationService(database)
          .migrateLegacyProfilePhotos(workspaceId);
    },
  );
}

// Keep the Drift import surface minimal without exposing Variable throughout
// the test body.
Variable<int> driftVariableInt(int value) => Variable<int>(value);
