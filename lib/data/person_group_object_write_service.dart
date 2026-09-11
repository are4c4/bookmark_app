import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'person_group_object_convergence_service.dart';
import 'person_group_store.dart';
import 'person_object_bridge.dart';
import 'relation_mutation_service.dart';
import 'system_object_store.dart';

class PersonGroupObjectWriteResult {
  const PersonGroupObjectWriteResult({
    required this.legacyGroupId,
    required this.canonicalObjectId,
  });

  final int legacyGroupId;
  final int canonicalObjectId;
}

/// Transitional write boundary for Person Group identity.
///
/// The generic Person Group Object is authoritative. Legacy `person_groups`
/// remains a compatibility projection until People-specific callers retire.
class PersonGroupObjectWriteService {
  PersonGroupObjectWriteService({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
    required this.personBridge,
  }) : _legacyGroups = PersonGroupStore(database),
       _genericStore = GenericDatabaseStore(database) {
    _convergence = PersonGroupObjectConvergenceService(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
      personBridge: personBridge,
    );
    _relationMutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: _genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: _genericStore,
        objectStore: objectStore,
      ),
    );
  }

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final PersonObjectBridge personBridge;
  final PersonGroupStore _legacyGroups;
  final GenericDatabaseStore _genericStore;
  late final PersonGroupObjectConvergenceService _convergence;
  late final RelationMutationService _relationMutations;

  Future<PersonGroupObjectWriteResult> create({
    required int workspaceId,
    required String name,
  }) async {
    final value = name.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Person Group name is empty.');
    }
    final schema = await _convergence.ensureSchema(workspaceId);
    return database.transaction(() async {
      final existingLegacy = (await _legacyGroups.listGroups())
          .where((group) => group.name.toLowerCase() == value.toLowerCase())
          .toList(growable: false);
      if (existingLegacy.length > 1) {
        throw StateError('Legacy Person Group name is ambiguous.');
      }
      if (existingLegacy.length == 1) {
        final legacy = existingLegacy.single;
        final canonical = await _canonicalForLegacy(
          schema: schema,
          legacyGroup: legacy,
        );
        return PersonGroupObjectWriteResult(
          legacyGroupId: legacy.id,
          canonicalObjectId: canonical.id,
        );
      }

      await _validatedClaims(schema);
      final canonicalObjectId = await objectStore.createObject(
        objectTypeId: schema.groupObjectType.id,
        title: value,
      );
      final legacyGroupId = await _legacyGroups.createGroup(value);
      await objectStore.setPropertyValue(
        objectId: canonicalObjectId,
        property: schema.legacyGroupIdProperty,
        value: legacyGroupId,
      );
      final legacy = (await _legacyGroups.listGroups()).singleWhere(
        (group) => group.id == legacyGroupId,
      );
      final canonical = await _canonicalForLegacy(
        schema: schema,
        legacyGroup: legacy,
      );
      return PersonGroupObjectWriteResult(
        legacyGroupId: legacyGroupId,
        canonicalObjectId: canonical.id,
      );
    });
  }

  Future<void> rename({
    required int workspaceId,
    required int legacyGroupId,
    required String name,
  }) async {
    final value = name.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Person Group name is empty.');
    }
    final schema = await _convergence.ensureSchema(workspaceId);
    await database.transaction(() async {
      final legacy = await _legacyGroup(legacyGroupId);
      final canonical = await _canonicalForLegacy(
        schema: schema,
        legacyGroup: legacy,
      );
      await objectStore.renameObject(canonical.id, value);
      await _legacyGroups.renameGroup(legacyGroupId, value);
      final committedLegacy = await _legacyGroup(legacyGroupId);
      final committedCanonical = await _canonicalForLegacy(
        schema: schema,
        legacyGroup: committedLegacy,
      );
      if (committedCanonical.title != value || committedLegacy.name != value) {
        throw StateError('Person Group rename did not commit consistently.');
      }
    });
  }

  Future<void> delete({
    required int workspaceId,
    required int legacyGroupId,
  }) async {
    final schema = await _convergence.ensureSchema(workspaceId);
    await database.transaction(() async {
      final legacy = await _legacyGroup(legacyGroupId);
      final canonical = await _canonicalForLegacy(
        schema: schema,
        legacyGroup: legacy,
      );
      await _relationMutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: schema.groupObjectType.id,
        objectId: canonical.id,
      );
      await _legacyGroups.deleteGroup(legacyGroupId);
      if ((await _legacyGroups.listGroups()).any(
        (group) => group.id == legacyGroupId,
      )) {
        throw StateError(
          'Legacy Person Group compatibility row survived delete.',
        );
      }
      final remainingClaims = await _validatedClaims(schema);
      if (remainingClaims.containsKey(legacyGroupId)) {
        throw StateError('Canonical Person Group identity survived delete.');
      }
    });
  }

  Future<PersonGroupInfo> _legacyGroup(int legacyGroupId) async {
    final matches = (await _legacyGroups.listGroups())
        .where((group) => group.id == legacyGroupId)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError('Legacy Person Group $legacyGroupId does not exist.');
    }
    return matches.single;
  }

  Future<AppObject> _canonicalForLegacy({
    required PersonGroupObjectSchema schema,
    required PersonGroupInfo legacyGroup,
  }) async {
    final claims = await _validatedClaims(schema);
    final objectId = claims[legacyGroup.id];
    if (objectId == null) {
      throw StateError(
        'Legacy Person Group ${legacyGroup.id} has no canonical identity.',
      );
    }
    final canonical = (await objectStore.listObjects(schema.groupObjectType.id))
        .singleWhere((object) => object.id == objectId);
    if (canonical.title != legacyGroup.name) {
      throw StateError(
        'Canonical Person Group title conflicts with legacy compatibility state.',
      );
    }
    return canonical;
  }

  Future<Map<int, int>> _validatedClaims(PersonGroupObjectSchema schema) async {
    final claims = <int, int>{};
    for (final object in await objectStore.listObjects(
      schema.groupObjectType.id,
    )) {
      final raw = object.values[schema.legacyGroupIdProperty.id];
      if (raw == null) continue;
      final legacyId = _legacyId(raw);
      if (legacyId == null) {
        throw StateError(
          'Canonical Person Group has a malformed legacy identity claim.',
        );
      }
      if (claims.containsKey(legacyId)) {
        throw StateError(
          'Legacy Person Group identity is ambiguous; multiple canonical Objects claim id $legacyId.',
        );
      }
      claims[legacyId] = object.id;
    }
    return claims;
  }

  int? _legacyId(dynamic raw) {
    if (raw is int && raw > 0) return raw;
    if (raw is double && raw > 0 && raw == raw.truncateToDouble()) {
      return raw.toInt();
    }
    return null;
  }
}
