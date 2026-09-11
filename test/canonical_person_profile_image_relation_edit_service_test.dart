import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_relation_editor_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_person_profile_image_relation_edit_service.dart';
import 'package:bookmark_app/services/person_profile_image_relation_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generic profile edit keeps mapped legacy Photo projection equivalent',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      await fixture.profileImages.migrateLegacyProfilePhoto(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      final before = await fixture.profileImages.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );

      await fixture.router.save(
        context: before.relation,
        selectedObjectIds: <int>[fixture.secondImageObjectId],
      );

      final after = await fixture.profileImages.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      expect(after.selectedImageObjectId, fixture.secondImageObjectId);
      expect(after.legacyProfilePhotoId, fixture.secondPhotoId);
      expect(await _legacyProfilePhotoId(fixture), fixture.secondPhotoId);
    },
  );

  test(
    'native canonical Image clears stale legacy projection but remains canonical',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      await fixture.profileImages.migrateLegacyProfilePhoto(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      final nativeImage = await fixture.images.findOrCreateManaged(
        workspaceId: fixture.workspaceId,
        filePath: 'images/native-person-profile.png',
        title: 'Native Person profile',
        originalFilename: 'native-person-profile.png',
      );
      final context = (await fixture.profileImages.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      ))
          .relation;

      await fixture.router.save(
        context: context,
        selectedObjectIds: <int>[nativeImage.id],
      );

      final after = await fixture.profileImages.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      expect(after.selectedImageObjectId, nativeImage.id);
      expect(after.legacyProfilePhotoId, isNull);
      expect(await _legacyProfilePhotoId(fixture), isNull);
    },
  );

  test('generic profile clear clears canonical and legacy projections', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    await fixture.profileImages.migrateLegacyProfilePhoto(
      workspaceId: fixture.workspaceId,
      personId: fixture.personId,
    );
    final context = (await fixture.profileImages.load(
      workspaceId: fixture.workspaceId,
      personId: fixture.personId,
    ))
        .relation;

    await fixture.router.save(
      context: context,
      selectedObjectIds: const <int>[],
    );

    final after = await fixture.profileImages.load(
      workspaceId: fixture.workspaceId,
      personId: fixture.personId,
    );
    expect(after.relation.selectedObjectIds, isEmpty);
    expect(after.legacyProfilePhotoId, isNull);
    expect(await _legacyProfilePhotoId(fixture), isNull);
  });

  test(
    'native canonical Person uses ordinary Relation semantics without legacy row',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final legacyState = await fixture.profileImages.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      final personSchema = await fixture.personBridge.ensurePersonObjectType(
        fixture.workspaceId,
      );
      final nativePersonId = await fixture.objectStore.createObject(
        objectTypeId: personSchema.objectType.id,
        title: 'Native Person',
      );
      final context = await fixture.targets.selectionFor(
        workspaceId: fixture.workspaceId,
        sourceObjectId: nativePersonId,
        property: legacyState.property,
      );

      await fixture.router.save(
        context: context,
        selectedObjectIds: <int>[fixture.firstImageObjectId],
      );

      final refreshed = await fixture.targets.selectionFor(
        workspaceId: fixture.workspaceId,
        sourceObjectId: nativePersonId,
        property: legacyState.property,
      );
      expect(refreshed.selectedObjectIds, <int>[fixture.firstImageObjectId]);
      expect(
        await fixture.personBridge.legacyPersonIdForObject(
          fixture.workspaceId,
          nativePersonId,
        ),
        isNull,
      );
      expect(await fixture.database.select(fixture.database.people).get(), hasLength(1));
    },
  );

  test(
    'missing legacy mapping fails closed before generic profile mutation',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      await fixture.profileImages.migrateLegacyProfilePhoto(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      final before = await fixture.profileImages.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      await fixture.database.customStatement(
        'DELETE FROM person_object_links WHERE workspace_id = ? AND person_id = ?',
        <Object>[fixture.workspaceId, fixture.personId],
      );

      await expectLater(
        fixture.router.save(
          context: before.relation,
          selectedObjectIds: <int>[fixture.secondImageObjectId],
        ),
        throwsStateError,
      );

      final stored = await fixture.targets.selectionFor(
        workspaceId: fixture.workspaceId,
        sourceObjectId: before.personObjectId,
        property: before.property,
      );
      expect(stored.selectedObjectIds, <int>[fixture.firstImageObjectId]);
      expect(await _legacyProfilePhotoId(fixture), fixture.firstPhotoId);
    },
  );
}

Future<_Fixture> _fixture() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final workspaceId = await WorkspaceStore(database).initialize();
  final genericStore = GenericDatabaseStore(database);
  final objectStore = ObjectStore(genericStore);
  final systemStore = SystemObjectStore(
    database: database,
    objectStore: objectStore,
  );
  final images = ImageObjectService(
    systemObjects: systemStore,
    defaultsStore: ObjectTypeDefaultsStore(genericStore),
  );
  final personBridge = PersonObjectBridge(
    database: database,
    objectStore: objectStore,
    systemObjectStore: systemStore,
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
    "INSERT INTO photos(path, title) VALUES ('photos/profile-a.jpg', 'Profile A')",
  );
  await database.customStatement(
    "INSERT INTO photos(path, title) VALUES ('photos/profile-b.jpg', 'Profile B')",
  );
  final firstPhotoId = (await database.customSelect(
    "SELECT id FROM photos WHERE path = 'photos/profile-a.jpg'",
  ).getSingle())
      .read<int>('id');
  final secondPhotoId = (await database.customSelect(
    "SELECT id FROM photos WHERE path = 'photos/profile-b.jpg'",
  ).getSingle())
      .read<int>('id');
  await database.customStatement(
    '''INSERT INTO people(name, profile_photo_id)
       VALUES ('Profile Person', ?)''',
    <Object>[firstPhotoId],
  );
  final personId = (await database.customSelect(
    "SELECT id FROM people WHERE name = 'Profile Person'",
  ).getSingle())
      .read<int>('id');

  await coreBridge.syncAll(workspaceId);
  final firstImageObjectId = await _mappedImageId(
    database,
    workspaceId: workspaceId,
    photoId: firstPhotoId,
  );
  final secondImageObjectId = await _mappedImageId(
    database,
    workspaceId: workspaceId,
    photoId: secondPhotoId,
  );
  final targets = RelationTargetService(objectStore);
  final genericEditor = ObjectRelationEditorService(
    targets: targets,
    mutations: RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    ),
  );

  return _Fixture(
    database: database,
    workspaceId: workspaceId,
    personId: personId,
    firstPhotoId: firstPhotoId,
    secondPhotoId: secondPhotoId,
    firstImageObjectId: firstImageObjectId,
    secondImageObjectId: secondImageObjectId,
    objectStore: objectStore,
    images: images,
    personBridge: personBridge,
    targets: targets,
    profileImages: PersonProfileImageRelationService(database),
    router: CanonicalPersonProfileImageRelationEditService.forDatabase(
      database: database,
      genericEditor: genericEditor,
    ),
  );
}

Future<int> _mappedImageId(
  AppDatabase database, {
  required int workspaceId,
  required int photoId,
}) async {
  final row = await database.customSelect(
    '''SELECT object_id FROM photo_object_links
       WHERE workspace_id = ? AND photo_id = ?''',
    variables: <Variable<int>>[
      Variable<int>(workspaceId),
      Variable<int>(photoId),
    ],
  ).getSingle();
  return row.read<int>('object_id');
}

Future<int?> _legacyProfilePhotoId(_Fixture fixture) async {
  final row = await (fixture.database.select(fixture.database.people)
        ..where((person) => person.id.equals(fixture.personId)))
      .getSingle();
  return row.profilePhotoId;
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.workspaceId,
    required this.personId,
    required this.firstPhotoId,
    required this.secondPhotoId,
    required this.firstImageObjectId,
    required this.secondImageObjectId,
    required this.objectStore,
    required this.images,
    required this.personBridge,
    required this.targets,
    required this.profileImages,
    required this.router,
  });

  final AppDatabase database;
  final int workspaceId;
  final int personId;
  final int firstPhotoId;
  final int secondPhotoId;
  final int firstImageObjectId;
  final int secondImageObjectId;
  final ObjectStore objectStore;
  final ImageObjectService images;
  final PersonObjectBridge personBridge;
  final RelationTargetService targets;
  final PersonProfileImageRelationService profileImages;
  final CanonicalPersonProfileImageRelationEditService router;
}
