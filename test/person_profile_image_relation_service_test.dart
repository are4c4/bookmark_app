import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/person_profile_image_relation_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy Person profile Photo migrates to one idempotent canonical single Image Relation',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);

      final first = await fixture.service.migrateLegacyProfilePhoto(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      final firstSnapshot = await _snapshot(fixture, first);
      final second = await fixture.service.migrateLegacyProfilePhoto(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );

      expect(first.selectedImageObjectId, fixture.firstImageObjectId);
      expect(first.legacyProfilePhotoId, fixture.firstPhotoId);
      expect(first.property.isRelation, isTrue);
      expect(first.property.targetObjectTypeId, first.imageObjectType.id);
      expect(first.property.allowsMultipleRelations, isFalse);
      expect(await _snapshot(fixture, second), firstSnapshot);

      final personType = (await fixture.systemStore.getSystemObjectType(
        workspaceId: fixture.workspaceId,
        systemKey: PersonObjectBridge.systemKey,
      ))!;
      final properties = personType.properties
          .where(
            (property) =>
                property.name ==
                PersonProfileImageRelationService.profileImagePropertyName,
          )
          .toList(growable: false);
      expect(properties, hasLength(1));

      final backlinks = await fixture.objectStore.backlinks(
        fixture.firstImageObjectId,
      );
      expect(
        backlinks.where(
          (edge) =>
              edge.sourceObjectId == first.personObjectId &&
              edge.propertyId == first.property.id,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'canonical retarget and clear keep legacy profile projection atomic and deterministic',
    () async {
      final fixture = await _fixture(migrate: true);
      addTearDown(fixture.database.close);

      var state = await fixture.service.setProfileImage(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
        imageObjectId: fixture.secondImageObjectId,
      );
      expect(state.selectedImageObjectId, fixture.secondImageObjectId);
      expect(state.legacyProfilePhotoId, fixture.secondPhotoId);

      final nativeImage = await fixture.images.findOrCreateManaged(
        workspaceId: fixture.workspaceId,
        filePath: 'images/native-profile.png',
        title: 'Native profile image',
        originalFilename: 'native-profile.png',
      );
      state = await fixture.service.setProfileImage(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
        imageObjectId: nativeImage.id,
      );
      expect(state.selectedImageObjectId, nativeImage.id);
      expect(
        state.legacyProfilePhotoId,
        isNull,
        reason: 'native Image has no safe legacy Photo projection',
      );

      state = await fixture.service.clearProfileImage(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      expect(state.selectedImageObjectId, isNull);
      expect(state.relation.selectedObjectIds, isEmpty);
      expect(state.legacyProfilePhotoId, isNull);
      expect(await _edgeSnapshot(fixture, state), isEmpty);
    },
  );

  test(
    'edge position drift fails closed without changing Relation or legacy projection',
    () async {
      final fixture = await _fixture(migrate: true);
      addTearDown(fixture.database.close);
      final state = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );

      await fixture.database.customStatement(
        'UPDATE object_relation_edges SET position = 7 '
        'WHERE source_object_id = ? AND property_id = ?',
        <Object>[state.personObjectId, state.property.id],
      );
      final before = await _snapshot(fixture, state);

      await expectLater(
        fixture.service.setProfileImage(
          workspaceId: fixture.workspaceId,
          personId: fixture.personId,
          imageObjectId: fixture.secondImageObjectId,
        ),
        throwsStateError,
      );

      expect(
        await _snapshot(
          fixture,
          await fixture.service.load(
            workspaceId: fixture.workspaceId,
            personId: fixture.personId,
          ),
        ),
        before,
      );
    },
  );

  test(
    'single-cardinality corruption fails closed without normalizing persisted state',
    () async {
      final fixture = await _fixture(migrate: true);
      addTearDown(fixture.database.close);
      final state = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );

      await fixture.genericStore.setValue(
        recordId: state.personObjectId,
        propertyId: state.property.id,
        value: <int>[
          fixture.firstImageObjectId,
          fixture.secondImageObjectId,
        ],
      );
      await fixture.database.customStatement(
        '''INSERT INTO object_relation_edges(
             source_object_id, property_id, target_object_id, position
           ) VALUES (?, ?, ?, ?)''',
        <Object>[
          state.personObjectId,
          state.property.id,
          fixture.secondImageObjectId,
          1,
        ],
      );
      final corrupt = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      expect(corrupt.relation.hasCardinalityViolation, isTrue);
      expect(corrupt.selectedImageObjectId, isNull);
      final before = await _snapshot(fixture, corrupt);

      await expectLater(
        fixture.service.clearProfileImage(
          workspaceId: fixture.workspaceId,
          personId: fixture.personId,
        ),
        throwsStateError,
      );

      expect(
        await _snapshot(
          fixture,
          await fixture.service.load(
            workspaceId: fixture.workspaceId,
            personId: fixture.personId,
          ),
        ),
        before,
      );
    },
  );

  test(
    'wrong-type Photo mapping fails closed without replacing canonical Relation',
    () async {
      final fixture = await _fixture(migrate: true);
      addTearDown(fixture.database.close);
      final state = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      final before = await _snapshot(fixture, state);

      await fixture.database.customStatement(
        '''UPDATE photo_object_links SET object_id = ?
           WHERE workspace_id = ? AND photo_id = ?''',
        <Object>[
          state.personObjectId,
          fixture.workspaceId,
          fixture.firstPhotoId,
        ],
      );

      await expectLater(
        fixture.service.migrateLegacyProfilePhoto(
          workspaceId: fixture.workspaceId,
          personId: fixture.personId,
        ),
        throwsStateError,
      );

      final after = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      expect(await _storedValue(fixture, after), before.storedValue);
      expect(await _edgeSnapshot(fixture, after), before.edges);
      expect(after.legacyProfilePhotoId, before.legacyProfilePhotoId);
    },
  );

  test(
    'legacy projection failure rolls back an otherwise valid canonical retarget',
    () async {
      final fixture = await _fixture(migrate: true);
      addTearDown(fixture.database.close);
      final state = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      final before = await _snapshot(fixture, state);

      await fixture.database.customStatement('''
        CREATE TRIGGER fail_profile_photo_projection
        BEFORE UPDATE OF profile_photo_id ON people
        BEGIN
          SELECT RAISE(ABORT, 'profile projection blocked');
        END
      ''');

      await expectLater(
        fixture.service.setProfileImage(
          workspaceId: fixture.workspaceId,
          personId: fixture.personId,
          imageObjectId: fixture.secondImageObjectId,
        ),
        throwsA(anything),
      );

      final after = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      expect(await _snapshot(fixture, after), before);
    },
  );

  test(
    'Relation-safe Image deletion detaches the surviving Person backlink',
    () async {
      final fixture = await _fixture(migrate: true);
      addTearDown(fixture.database.close);
      final before = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );

      final mutations = RelationMutationService(
        objectStore: fixture.objectStore,
        genericStore: fixture.genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: fixture.genericStore,
          objectStore: fixture.objectStore,
        ),
      );
      await mutations.deleteObject(
        workspaceId: fixture.workspaceId,
        objectTypeId: before.imageObjectType.id,
        objectId: fixture.firstImageObjectId,
      );

      final after = await fixture.service.load(
        workspaceId: fixture.workspaceId,
        personId: fixture.personId,
      );
      expect(after.relation.selectedObjectIds, isEmpty);
      expect(after.selectedImageObjectId, isNull);
      expect(await _edgeSnapshot(fixture, after), isEmpty);
      expect(
        await fixture.objectStore.backlinks(fixture.firstImageObjectId),
        isEmpty,
      );
    },
  );
}

Future<_Fixture> _fixture({bool migrate = false}) async {
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
  final service = PersonProfileImageRelationService(database);
  if (migrate) {
    await service.migrateLegacyProfilePhoto(
      workspaceId: workspaceId,
      personId: personId,
    );
  }

  return _Fixture(
    database: database,
    workspaceId: workspaceId,
    personId: personId,
    firstPhotoId: firstPhotoId,
    secondPhotoId: secondPhotoId,
    firstImageObjectId: firstImageObjectId,
    secondImageObjectId: secondImageObjectId,
    genericStore: genericStore,
    objectStore: objectStore,
    systemStore: systemStore,
    images: images,
    service: service,
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

Future<_Snapshot> _snapshot(
  _Fixture fixture,
  PersonProfileImageRelationState state,
) async {
  return _Snapshot(
    storedValue: await _storedValue(fixture, state),
    edges: await _edgeSnapshot(fixture, state),
    legacyProfilePhotoId: state.legacyProfilePhotoId,
  );
}

Future<String> _storedValue(
  _Fixture fixture,
  PersonProfileImageRelationState state,
) async {
  final personType = (await fixture.systemStore.getSystemObjectType(
    workspaceId: fixture.workspaceId,
    systemKey: PersonObjectBridge.systemKey,
  ))!;
  final record = (await fixture.genericStore.listRecords(personType.id))
      .singleWhere((candidate) => candidate.id == state.personObjectId);
  return jsonEncode(record.values[state.property.id]);
}

Future<List<String>> _edgeSnapshot(
  _Fixture fixture,
  PersonProfileImageRelationState state,
) async {
  final rows = await fixture.database.customSelect(
    '''SELECT target_object_id, position
       FROM object_relation_edges
       WHERE source_object_id = ? AND property_id = ?
       ORDER BY position, target_object_id''',
    variables: <Variable<int>>[
      Variable<int>(state.personObjectId),
      Variable<int>(state.property.id),
    ],
  ).get();
  return rows
      .map(
        (row) =>
            '${row.read<int>('target_object_id')}:${row.read<int>('position')}',
      )
      .toList(growable: false);
}

class _Snapshot {
  const _Snapshot({
    required this.storedValue,
    required this.edges,
    required this.legacyProfilePhotoId,
  });

  final String storedValue;
  final List<String> edges;
  final int? legacyProfilePhotoId;

  @override
  bool operator ==(Object other) =>
      other is _Snapshot &&
      storedValue == other.storedValue &&
      _listEquals(edges, other.edges) &&
      legacyProfilePhotoId == other.legacyProfilePhotoId;

  @override
  int get hashCode => Object.hash(
        storedValue,
        Object.hashAll(edges),
        legacyProfilePhotoId,
      );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
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
    required this.genericStore,
    required this.objectStore,
    required this.systemStore,
    required this.images,
    required this.service,
  });

  final AppDatabase database;
  final int workspaceId;
  final int personId;
  final int firstPhotoId;
  final int secondPhotoId;
  final int firstImageObjectId;
  final int secondImageObjectId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final SystemObjectStore systemStore;
  final ImageObjectService images;
  final PersonProfileImageRelationService service;
}
