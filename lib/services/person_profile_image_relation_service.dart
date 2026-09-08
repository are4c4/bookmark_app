import 'package:drift/drift.dart' show Value, Variable;

import '../data/app_database.dart';
import '../data/bidirectional_relation_store.dart';
import '../data/generic_database_store.dart';
import '../data/image_object_service.dart';
import '../data/object_alias_store.dart';
import '../data/object_identity_search_service.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_store.dart';
import '../data/person_object_bridge.dart';
import '../data/relation_mutation_service.dart';
import '../data/relation_target_service.dart';
import '../data/system_object_store.dart';
import '../domain/object_identity_search.dart';
import '../domain/object_model.dart';

/// Integrity boundary for the canonical Person -> Profile Image Relation.
///
/// `Person.profilePhotoId` remains a temporary compatibility projection while
/// People UI still reads legacy Photo rows. Canonical Image Relations are the
/// long-term authority: legacy migration consumes only the established
/// `photo_object_links` mapping, and canonical retarget/clear operations update
/// the legacy projection in the same database transaction.
class PersonProfileImageRelationService {
  PersonProfileImageRelationService(this.database);

  static const String profileImagePropertyName = 'Profile Image';

  final AppDatabase database;

  late final GenericDatabaseStore _genericStore = GenericDatabaseStore(database);
  late final ObjectStore objectStore = ObjectStore(_genericStore);
  late final SystemObjectStore _systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
  late final PersonObjectBridge _people = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: _systemObjects,
      );
  late final ImageObjectService _images = ImageObjectService(
        systemObjects: _systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(_genericStore),
      );
  late final RelationTargetService _targets = RelationTargetService(objectStore);
  late final RelationMutationService _mutations = RelationMutationService(
        objectStore: objectStore,
        genericStore: _genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: _genericStore,
          objectStore: objectStore,
        ),
      );

  late final ObjectIdentitySearchService _identitySearch =
      ObjectIdentitySearchService(
        objectStore: objectStore,
        aliasStore: ObjectAliasStore(_genericStore),
      );

  /// Loads the canonical profile-image Relation plus legacy compatibility state.
  /// Schema provisioning is deterministic and rejects an incompatible existing
  /// `Profile Image` Property rather than creating a second relationship path.
  Future<PersonProfileImageRelationState> load({
    required int workspaceId,
    required int personId,
  }) async {
    final person = await _requirePerson(personId);
    await _people.syncLegacyPeople(workspaceId);
    final profileImageProperty = await _ensureProfileImageProperty(workspaceId);
    final personObjectId = await _requirePersonObjectId(
      workspaceId: workspaceId,
      personId: personId,
    );
    final relation = await _targets.selectionFor(
      workspaceId: workspaceId,
      sourceObjectId: personObjectId,
      property: profileImageProperty,
    );
    return PersonProfileImageRelationState(
      workspaceId: workspaceId,
      personId: personId,
      personObjectId: personObjectId,
      legacyProfilePhotoId: person.profilePhotoId,
      relation: relation,
    );
  }

  Future<List<ObjectIdentitySearchResult>> searchImages({
    required PersonProfileImageRelationState state,
    required String query,
  }) =>
      _identitySearch.search(
        workspaceId: state.workspaceId,
        objectTypeId: state.imageObjectType.id,
        query: query,
      );

  /// Migrates every currently promotable legacy profile photo in one pass.
  ///
  /// A healthy legacy Photo whose canonical Image mapping is not available yet
  /// is skipped and can be retried by a later Object sync. This is the same
  /// fail-safe behavior as legacy Photo promotion when a managed file is
  /// temporarily unavailable. Once a mapping exists, every candidate is
  /// strictly preflighted before the first Relation write. Corrupt/ambiguous
  /// mappings, Relation value/index drift, wrong targets, or conflicting
  /// canonical selections abort the whole transaction. Existing matching
  /// selections are left untouched, so repeated migration is deterministic.
  Future<void> migrateLegacyProfilePhotos(int workspaceId) async {
    await _people.syncLegacyPeople(workspaceId);
    final profileImageProperty = await _ensureProfileImageProperty(workspaceId);
    final people = await database.select(database.people).get();
    final candidates = people
        .where((person) => person.profilePhotoId != null)
        .map((person) => person.id)
        .toList(growable: false);
    if (candidates.isEmpty || !await _photoMappingTableExists()) return;

    await database.transaction(() async {
      final plans = <_ProfileImageMigrationPlan>[];
      for (final personId in candidates) {
        final person = await _requirePerson(personId);
        final legacyPhotoId = person.profilePhotoId;
        if (legacyPhotoId == null) continue;
        final personObjectId = await _requirePersonObjectId(
          workspaceId: workspaceId,
          personId: personId,
        );
        final trusted = await _targets.selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: personObjectId,
          property: profileImageProperty,
        );
        final imageObjectId = await _imageObjectIdForLegacyPhoto(
          workspaceId: workspaceId,
          photoId: legacyPhotoId,
          trustedRelation: trusted,
          allowMissingMapping: true,
        );
        if (imageObjectId == null) continue;

        if (trusted.selectedObjectIds.isEmpty) {
          plans.add(
            _ProfileImageMigrationPlan(
              personObjectId: personObjectId,
              imageObjectId: imageObjectId,
            ),
          );
          continue;
        }
        if (trusted.selectedObjectIds.single != imageObjectId) {
          throw StateError(
            'Legacy Person profile Photo conflicts with an existing canonical Profile Image Relation.',
          );
        }
      }

      for (final plan in plans) {
        await _mutations.setRelation(
          objectId: plan.personObjectId,
          property: profileImageProperty,
          targetObjectIds: <int>[plan.imageObjectId],
        );
      }
    });
  }

  /// Migrates one Person through the established Photo -> Image mapping.
  Future<PersonProfileImageRelationState> migrateLegacyProfilePhoto({
    required int workspaceId,
    required int personId,
  }) async {
    await _requirePerson(personId);
    await _people.syncLegacyPeople(workspaceId);
    final profileImageProperty = await _ensureProfileImageProperty(workspaceId);

    await database.transaction(() async {
      final person = await _requirePerson(personId);
      final legacyPhotoId = person.profilePhotoId;
      if (legacyPhotoId == null) return;
      final personObjectId = await _requirePersonObjectId(
        workspaceId: workspaceId,
        personId: personId,
      );
      final trusted = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: personObjectId,
        property: profileImageProperty,
      );
      final imageObjectId = await _imageObjectIdForLegacyPhoto(
        workspaceId: workspaceId,
        photoId: legacyPhotoId,
        trustedRelation: trusted,
      );
      if (imageObjectId == null) {
        throw StateError(
          'Legacy Person profile Photo has no canonical Image mapping.',
        );
      }

      if (trusted.selectedObjectIds.isEmpty) {
        await _mutations.setRelation(
          objectId: personObjectId,
          property: profileImageProperty,
          targetObjectIds: <int>[imageObjectId],
        );
        return;
      }
      if (trusted.selectedObjectIds.single != imageObjectId) {
        throw StateError(
          'Legacy Person profile Photo conflicts with an existing canonical Profile Image Relation.',
        );
      }
    });

    return load(workspaceId: workspaceId, personId: personId);
  }

  /// Makes one canonical Image the Person profile image.
  ///
  /// If the Image is still backed by a legacy Photo mapping, `profilePhotoId`
  /// follows that Photo. A native canonical Image has no Photo representation,
  /// so the compatibility projection is cleared rather than left pointing to a
  /// stale previous image. Relation and projection changes are atomic.
  Future<PersonProfileImageRelationState> setProfileImage({
    required int workspaceId,
    required int personId,
    required int imageObjectId,
  }) async {
    await _requirePerson(personId);
    await _people.syncLegacyPeople(workspaceId);
    final profileImageProperty = await _ensureProfileImageProperty(workspaceId);

    await database.transaction(() async {
      final personObjectId = await _requirePersonObjectId(
        workspaceId: workspaceId,
        personId: personId,
      );
      final trusted = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: personObjectId,
        property: profileImageProperty,
      );
      if (!trusted.candidates.any((image) => image.id == imageObjectId)) {
        throw ArgumentError.value(
          imageObjectId,
          'imageObjectId',
          'Profile Image must be a canonical Image in the same workspace.',
        );
      }
      final legacyPhotoId = await _legacyPhotoIdForImage(
        workspaceId: workspaceId,
        imageObjectId: imageObjectId,
      );

      await _mutations.setRelation(
        objectId: personObjectId,
        property: profileImageProperty,
        targetObjectIds: <int>[imageObjectId],
      );
      await _writeLegacyProfilePhoto(
        personId: personId,
        photoId: legacyPhotoId,
      );
    });

    return load(workspaceId: workspaceId, personId: personId);
  }

  /// Clears canonical and legacy profile-image projections atomically.
  Future<PersonProfileImageRelationState> clearProfileImage({
    required int workspaceId,
    required int personId,
  }) async {
    await _requirePerson(personId);
    await _people.syncLegacyPeople(workspaceId);
    final profileImageProperty = await _ensureProfileImageProperty(workspaceId);

    await database.transaction(() async {
      final personObjectId = await _requirePersonObjectId(
        workspaceId: workspaceId,
        personId: personId,
      );
      await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: personObjectId,
        property: profileImageProperty,
      );
      await _mutations.setRelation(
        objectId: personObjectId,
        property: profileImageProperty,
        targetObjectIds: const <int>[],
      );
      await _writeLegacyProfilePhoto(personId: personId, photoId: null);
    });

    return load(workspaceId: workspaceId, personId: personId);
  }

  Future<ObjectPropertyDefinition> _ensureProfileImageProperty(
    int workspaceId,
  ) async {
    final personSchema = await _people.ensurePersonObjectType(workspaceId);
    final imageDefinition = await _images.ensureDefinition(workspaceId);
    return _systemObjects.ensureRelationProperty(
      objectTypeId: personSchema.objectType.id,
      name: profileImagePropertyName,
      targetObjectTypeId: imageDefinition.objectType.id,
      multiple: false,
    );
  }

  Future<Person> _requirePerson(int personId) async {
    final person = await (database.select(database.people)
          ..where((row) => row.id.equals(personId)))
        .getSingleOrNull();
    if (person == null) {
      throw ArgumentError.value(
        personId,
        'personId',
        'Legacy Person does not exist.',
      );
    }
    return person;
  }

  Future<int> _requirePersonObjectId({
    required int workspaceId,
    required int personId,
  }) async {
    final objectId = await _people.objectIdForLegacyPerson(workspaceId, personId);
    if (objectId == null) {
      throw StateError(
        'Legacy Person must be mirrored to one canonical Person Object before Profile Image mutation.',
      );
    }
    return objectId;
  }

  Future<int?> _imageObjectIdForLegacyPhoto({
    required int workspaceId,
    required int photoId,
    required RelationSelectionContext trustedRelation,
    bool allowMissingMapping = false,
  }) async {
    final photo = await (database.select(database.photos)
          ..where((row) => row.id.equals(photoId)))
        .getSingleOrNull();
    if (photo == null) {
      throw StateError(
        'Legacy Person profile Photo points to a missing Photo row.',
      );
    }
    if (!await _photoMappingTableExists()) {
      if (allowMissingMapping) return null;
      throw StateError(
        'Legacy Photo -> Image mapping is unavailable; refusing to manufacture a replacement.',
      );
    }

    final rows = await database.customSelect(
      '''SELECT object_id FROM photo_object_links
         WHERE workspace_id = ? AND photo_id = ?''',
      variables: <Variable<int>>[
        Variable<int>(workspaceId),
        Variable<int>(photoId),
      ],
    ).get();
    if (rows.isEmpty && allowMissingMapping) return null;
    if (rows.length != 1) {
      throw StateError(
        'Legacy Person profile Photo does not have one unambiguous canonical Image mapping.',
      );
    }
    final imageObjectId = rows.single.read<int>('object_id');
    if (!trustedRelation.candidates.any((image) => image.id == imageObjectId)) {
      throw StateError(
        'Legacy Person profile Photo mapping does not target a canonical Image in this workspace.',
      );
    }

    final reverseRows = await database.customSelect(
      '''SELECT photo_id FROM photo_object_links
         WHERE workspace_id = ? AND object_id = ?''',
      variables: <Variable<int>>[
        Variable<int>(workspaceId),
        Variable<int>(imageObjectId),
      ],
    ).get();
    if (reverseRows.length != 1 ||
        reverseRows.single.read<int>('photo_id') != photoId) {
      throw StateError(
        'Legacy Photo -> Image mapping is ambiguous or inconsistent.',
      );
    }
    return imageObjectId;
  }

  Future<int?> _legacyPhotoIdForImage({
    required int workspaceId,
    required int imageObjectId,
  }) async {
    if (!await _photoMappingTableExists()) return null;
    final rows = await database.customSelect(
      '''SELECT photo_id FROM photo_object_links
         WHERE workspace_id = ? AND object_id = ?''',
      variables: <Variable<int>>[
        Variable<int>(workspaceId),
        Variable<int>(imageObjectId),
      ],
    ).get();
    if (rows.isEmpty) return null;
    if (rows.length != 1) {
      throw StateError('Canonical Image has an ambiguous legacy Photo mapping.');
    }
    final photoId = rows.single.read<int>('photo_id');
    final photo = await (database.select(database.photos)
          ..where((row) => row.id.equals(photoId)))
        .getSingleOrNull();
    if (photo == null) {
      throw StateError('Canonical Image maps to a missing legacy Photo row.');
    }
    return photoId;
  }

  Future<bool> _photoMappingTableExists() async {
    final row = await database.customSelect(
      '''SELECT name FROM sqlite_master
         WHERE type = 'table' AND name = 'photo_object_links' LIMIT 1''',
    ).getSingleOrNull();
    return row != null;
  }

  Future<void> _writeLegacyProfilePhoto({
    required int personId,
    required int? photoId,
  }) async {
    final changed = await (database.update(database.people)
          ..where((person) => person.id.equals(personId)))
        .write(
      PeopleCompanion(
        profilePhotoId: Value<int?>(photoId),
      ),
    );
    if (changed != 1) {
      throw StateError(
        'Legacy Person disappeared while updating the profile-image compatibility projection.',
      );
    }
  }
}

class PersonProfileImageRelationState {
  const PersonProfileImageRelationState({
    required this.workspaceId,
    required this.personId,
    required this.personObjectId,
    required this.legacyProfilePhotoId,
    required this.relation,
  });

  final int workspaceId;
  final int personId;
  final int personObjectId;
  final int? legacyProfilePhotoId;
  final RelationSelectionContext relation;

  ObjectPropertyDefinition get property => relation.property;
  AppObjectType get imageObjectType => relation.targetObjectType;
  List<AppObject> get selectedImages => relation.selectedObjects;

  int? get selectedImageObjectId {
    if (relation.hasCardinalityViolation ||
        relation.missingTargetObjectIds.isNotEmpty ||
        relation.selectedObjects.length != 1) {
      return null;
    }
    return relation.selectedObjects.single.id;
  }

  bool get hasDiagnostics =>
      relation.hasCardinalityViolation ||
      relation.missingTargetObjectIds.isNotEmpty;
}

class _ProfileImageMigrationPlan {
  const _ProfileImageMigrationPlan({
    required this.personObjectId,
    required this.imageObjectId,
  });

  final int personObjectId;
  final int imageObjectId;
}
