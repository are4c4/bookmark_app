import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/canonical_object_mutation_impact_sink.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_relation_editor_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:bookmark_app/services/canonical_person_profile_image_relation_edit_service.dart';
import 'package:bookmark_app/services/person_profile_image_relation_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Profile Image compatibility edit refreshes canonical relation-label Search', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final search = ObjectGlobalSearchService(genericStore);
    final sink = CanonicalObjectMutationImpactSink(
      onObjectCommitted: search.refreshObjectLabelDependents,
      onDeletionCommitted: (impact) async {},
    );
    final workspaceStore = WorkspaceStore(
      database,
      canonicalObjectMutationImpactSink: sink,
    );
    final workspaceId = await workspaceStore.initialize();
    final objectStore = ObjectStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final coreBridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemStore,
      ),
    );

    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photos/profile-a.jpg', 'Profile Alpha')",
    );
    await database.customStatement(
      "INSERT INTO photos(path, title) VALUES ('photos/profile-b.jpg', 'Profile Beta')",
    );
    final photos = await database.select(database.photos).get();
    final firstPhoto = photos.firstWhere((photo) => photo.title == 'Profile Alpha');
    final secondPhoto = photos.firstWhere((photo) => photo.title == 'Profile Beta');
    await database.customStatement(
      'INSERT INTO people(name, profile_photo_id) VALUES (?, ?)',
      <Object>['Profile Person', firstPhoto.id],
    );
    final person = (await database.select(database.people).get()).single;
    await coreBridge.syncAll(workspaceId);

    final profileImages = PersonProfileImageRelationService(database);
    await profileImages.migrateLegacyProfilePhoto(
      workspaceId: workspaceId,
      personId: person.id,
    );
    final initial = await profileImages.load(
      workspaceId: workspaceId,
      personId: person.id,
    );
    final secondImageId = (await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
      variables: <Variable<int>>[
        Variable<int>(workspaceId),
        Variable<int>(secondPhoto.id),
      ],
    ).getSingle()).read<int>('object_id');

    final genericEditor = ObjectRelationEditorService(
      targets: RelationTargetService(objectStore),
      mutations: RelationMutationService(
        objectStore: objectStore,
        genericStore: genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
      ),
    );
    final router = CanonicalPersonProfileImageRelationEditService.forDatabase(
      database: database,
      genericEditor: genericEditor,
    );
    final index = ObjectSearchRepository(genericStore);
    await search.rebuildWorkspace(workspaceId);

    expect(
      (await index.search(workspaceId: workspaceId, rawQuery: 'alpha'))
          .map((hit) => hit.objectId),
      contains(initial.personObjectId),
    );

    await router.save(
      context: initial.relation,
      selectedObjectIds: <int>[secondImageId],
    );

    expect(
      (await index.search(workspaceId: workspaceId, rawQuery: 'alpha'))
          .map((hit) => hit.objectId),
      isNot(contains(initial.personObjectId)),
    );
    expect(
      (await index.search(workspaceId: workspaceId, rawQuery: 'beta'))
          .map((hit) => hit.objectId),
      contains(initial.personObjectId),
    );
  });
}
