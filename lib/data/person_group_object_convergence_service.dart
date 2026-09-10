import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'person_group_store.dart';
import 'person_object_bridge.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';
import 'system_object_store.dart';

class PersonGroupObjectSchema {
  const PersonGroupObjectSchema({
    required this.groupObjectType,
    required this.legacyGroupIdProperty,
    required this.personGroupsProperty,
  });

  final AppObjectType groupObjectType;
  final ObjectPropertyDefinition legacyGroupIdProperty;
  final ObjectPropertyDefinition personGroupsProperty;
}

/// Preservation-safe bridge from legacy People groups to generic Objects and
/// the canonical Relation subsystem.
///
/// Legacy group/member rows remain compatibility input. A legacy group receives
/// one stable `Person Group` Object identity through its hidden legacy id, while
/// Person membership is represented by the canonical many `Groups` Relation.
/// Existing independently-edited canonical membership is never overwritten: a
/// mismatch fails closed and the enclosing transaction rolls back the pass.
class PersonGroupObjectConvergenceService {
  PersonGroupObjectConvergenceService({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
    required this.personBridge,
  }) : _genericStore = GenericDatabaseStore(database),
       _legacyGroups = PersonGroupStore(database) {
    _targets = RelationTargetService(objectStore);
    _mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: _genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: _genericStore,
        objectStore: objectStore,
      ),
    );
  }

  static const groupSystemKey = 'personGroup';
  static const legacyGroupIdPropertyName = 'Legacy Person Group ID';
  static const personGroupsPropertyName = 'Groups';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final PersonObjectBridge personBridge;
  final GenericDatabaseStore _genericStore;
  final PersonGroupStore _legacyGroups;
  late final RelationTargetService _targets;
  late final RelationMutationService _mutations;

  Future<PersonGroupObjectSchema> ensureSchema(int workspaceId) async {
    final person = await personBridge.ensurePersonObjectType(workspaceId);
    final groupType = await systemObjectStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: groupSystemKey,
      name: 'Person Group',
      icon: '👥',
    );
    final legacyId = await systemObjectStore.ensureProperty(
      objectTypeId: groupType.id,
      name: legacyGroupIdPropertyName,
      type: ObjectPropertyType.number,
      config: const <String, dynamic>{
        'system': true,
        'hidden': true,
        ObjectPropertyDefinition.identityManagedConfigKey: true,
      },
    );
    if (legacyId.type != ObjectPropertyType.number ||
        legacyId.config[ObjectPropertyDefinition.identityManagedConfigKey] != true) {
      throw StateError(
        'Existing Person Group legacy identity Property is incompatible.',
      );
    }
    final groups = await systemObjectStore.ensureRelationProperty(
      objectTypeId: person.objectType.id,
      name: personGroupsPropertyName,
      targetObjectTypeId: groupType.id,
      multiple: true,
    );
    final refreshedGroupType = (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: groupSystemKey,
    ))!;
    return PersonGroupObjectSchema(
      groupObjectType: refreshedGroupType,
      legacyGroupIdProperty: refreshedGroupType.properties.singleWhere(
        (property) => property.id == legacyId.id,
      ),
      personGroupsProperty: groups,
    );
  }

  Future<List<int>> converge(int workspaceId) async {
    await personBridge.syncLegacyPeople(workspaceId);
    final schema = await ensureSchema(workspaceId);
    return database.transaction(() async {
      final legacyGroups = await _legacyGroups.listGroups();
      final existingGroupObjects = await objectStore.listObjects(
        schema.groupObjectType.id,
      );
      final managedExisting = existingGroupObjects
          .where(
            (object) =>
                _legacyId(object.values[schema.legacyGroupIdProperty.id]) != null,
          )
          .toList(growable: false);
      final isInitialBootstrap = managedExisting.isEmpty;
      final groupObjectIds = <int, int>{};
      final touched = <int>[];

      for (final group in legacyGroups) {
        final objectId = await _groupObjectFor(
          schema: schema,
          legacyGroup: group,
          allowCreate: isInitialBootstrap,
        );
        groupObjectIds[group.id] = objectId;
      }

      final people = await database.select(database.people).get();
      for (final person in people) {
        final personObjectId = await personBridge.objectIdForLegacyPerson(
          workspaceId,
          person.id,
        );
        if (personObjectId == null) {
          throw StateError(
            'Legacy Person ${person.id} has no canonical Person Object.',
          );
        }
        final legacyMembership = await _legacyGroups.groupsForPerson(person.id);
        final expected = legacyMembership
            .map((group) => groupObjectIds[group.id])
            .whereType<int>()
            .toList(growable: false);
        if (expected.length != legacyMembership.length) {
          throw StateError(
            'Legacy Person group membership references an unmapped group.',
          );
        }

        final current = await _targets.selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: personObjectId,
          property: schema.personGroupsProperty,
        );
        if (_sameIds(current.selectedObjectIds, expected)) continue;
        if (!isInitialBootstrap || current.selectedObjectIds.isNotEmpty) {
          throw StateError(
            'Canonical Person group membership conflicts with legacy compatibility state.',
          );
        }
        await _mutations.setRelation(
          objectId: personObjectId,
          property: schema.personGroupsProperty,
          targetObjectIds: expected,
        );
        if (expected.isNotEmpty) touched.add(personObjectId);
      }

      touched.sort();
      return List<int>.unmodifiable(touched);
    });
  }

  Future<int> _groupObjectFor({
    required PersonGroupObjectSchema schema,
    required PersonGroupInfo legacyGroup,
    required bool allowCreate,
  }) async {
    final matches = (await objectStore.listObjects(schema.groupObjectType.id))
        .where(
          (object) =>
              _legacyId(object.values[schema.legacyGroupIdProperty.id]) ==
              legacyGroup.id,
        )
        .toList(growable: false);
    if (matches.length > 1) {
      throw StateError(
        'Legacy Person Group identity is ambiguous; multiple canonical Objects claim id ${legacyGroup.id}.',
      );
    }
    if (matches.length == 1) {
      final existing = matches.single;
      if (existing.title != legacyGroup.name) {
        throw StateError(
          'Canonical Person Group title conflicts with legacy compatibility state.',
        );
      }
      return existing.id;
    }
    if (!allowCreate) {
      throw StateError(
        'Legacy Person Group has no canonical identity after bootstrap.',
      );
    }

    final objectId = await objectStore.createObject(
      objectTypeId: schema.groupObjectType.id,
      title: legacyGroup.name,
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: schema.legacyGroupIdProperty,
      value: legacyGroup.id,
    );
    return objectId;
  }

  int? _legacyId(dynamic raw) {
    if (raw is int && raw > 0) return raw;
    if (raw is double && raw > 0 && raw == raw.truncateToDouble()) {
      return raw.toInt();
    }
    return null;
  }

  bool _sameIds(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
