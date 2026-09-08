import 'dart:io';

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
    'Object sync leaves unavailable legacy profile Photo mapping retryable',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'person_profile_image_retry_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        profileDirectoryPath: directory.path,
      );
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();

      await database.customStatement(
        "INSERT INTO photos(path, title) VALUES ('photos/missing-profile.jpg', 'Missing profile')",
      );
      final photoId = (await database.customSelect(
        "SELECT id FROM photos WHERE path = 'photos/missing-profile.jpg'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        '''INSERT INTO people(name, profile_photo_id)
           VALUES ('Missing Profile Person', ?)''',
        <Object>[photoId],
      );
      final personId = (await database.customSelect(
        "SELECT id FROM people WHERE name = 'Missing Profile Person'",
      ).getSingle())
          .read<int>('id');

      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);
      await sync.syncWorkspace(workspaceId);

      final mapping = await database.customSelect(
        'SELECT object_id FROM photo_object_links WHERE photo_id = $photoId',
      ).getSingleOrNull();
      expect(
        mapping,
        isNull,
        reason: 'missing managed file must not manufacture an Image identity',
      );

      final state = await PersonProfileImageRelationService(database).load(
        workspaceId: workspaceId,
        personId: personId,
      );
      expect(state.relation.selectedObjectIds, isEmpty);
      expect(state.selectedImageObjectId, isNull);
      expect(state.legacyProfilePhotoId, photoId);

      await PersonProfileImageRelationService(database)
          .migrateLegacyProfilePhotos(workspaceId);
      final unchanged = await PersonProfileImageRelationService(database).load(
        workspaceId: workspaceId,
        personId: personId,
      );
      expect(unchanged.relation.selectedObjectIds, isEmpty);
      expect(unchanged.legacyProfilePhotoId, photoId);
    },
  );
}
