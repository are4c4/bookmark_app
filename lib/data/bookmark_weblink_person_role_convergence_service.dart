import 'package:drift/drift.dart' show Variable;

import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'person_object_bridge.dart';
import 'person_roles.dart';
import 'relation_mutation_service.dart';
import 'relation_target_service.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';

class BookmarkWeblinkPersonRoleSourceSnapshot {
  BookmarkWeblinkPersonRoleSourceSnapshot(
    Map<int, Map<String, List<int>>> rolePersonIdsByBookmarkObjectId, {
    required Map<int, int?> weblinkObjectIdByBookmarkObjectId,
  }) : _rolePersonIdsByBookmarkObjectId =
           Map<int, Map<String, List<int>>>.unmodifiable(
             rolePersonIdsByBookmarkObjectId.map<int, Map<String, List<int>>>(
               (objectId, roles) => MapEntry<int, Map<String, List<int>>>(
                 objectId,
                 Map<String, List<int>>.unmodifiable(
                   roles.map<String, List<int>>(
                     (role, ids) => MapEntry<String, List<int>>(
                       role,
                       List<int>.unmodifiable(ids),
                     ),
                   ),
                 ),
               ),
             ),
           ),
       _weblinkObjectIdByBookmarkObjectId = Map<int, int?>.unmodifiable(
         weblinkObjectIdByBookmarkObjectId,
       );

  static final empty = BookmarkWeblinkPersonRoleSourceSnapshot(
    const <int, Map<String, List<int>>>{},
    weblinkObjectIdByBookmarkObjectId: const <int, int?>{},
  );

  final Map<int, Map<String, List<int>>> _rolePersonIdsByBookmarkObjectId;
  final Map<int, int?> _weblinkObjectIdByBookmarkObjectId;

  List<int>? personIdsFor(int bookmarkObjectId, String role) =>
      _rolePersonIdsByBookmarkObjectId[bookmarkObjectId]?[role];

  bool wasLinkedTo(int bookmarkObjectId, int weblinkObjectId) =>
      _weblinkObjectIdByBookmarkObjectId.containsKey(bookmarkObjectId) &&
      _weblinkObjectIdByBookmarkObjectId[bookmarkObjectId] == weblinkObjectId;
}

class BookmarkWeblinkPersonRoleConvergenceReport {
  const BookmarkWeblinkPersonRoleConvergenceReport({
    required this.bookmarkCount,
    required this.weblinkCount,
    required this.roleCount,
    required this.convergedWeblinkCount,
    required this.unchangedWeblinkCount,
    this.mutatedWeblinkObjectIds = const <int>[],
  });

  static const empty = BookmarkWeblinkPersonRoleConvergenceReport(
    bookmarkCount: 0,
    weblinkCount: 0,
    roleCount: 0,
    convergedWeblinkCount: 0,
    unchangedWeblinkCount: 0,
  );

  final int bookmarkCount;
  final int weblinkCount;
  final int roleCount;
  final int convergedWeblinkCount;
  final int unchangedWeblinkCount;
  final List<int> mutatedWeblinkObjectIds;
}

/// Converges legacy Bookmark Person-role assignments onto canonical role-bearing
/// Weblink -> Person Relations without adding another edge authority.
///
/// Transition-only Bookmark Objects retain hidden role Relations only as the
/// previous-source checkpoint used by normal compatibility reconciliation. The
/// public canonical role state lives on Weblink Objects. Every read/write uses
/// the canonical Relation subsystem and all source refresh + target convergence
/// happens in one workspace transaction so a conflict cannot advance the
/// checkpoint without advancing the canonical target.
class BookmarkWeblinkPersonRoleConvergenceService {
  BookmarkWeblinkPersonRoleConvergenceService({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
    required this.personBridge,
  }) : _genericStore = GenericDatabaseStore(database) {
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

  static const bookmarkSystemKey = 'bookmark';
  static const bookmarkWeblinkRelationName = 'Weblink';
  static const roleMetadataKey = 'personRole';
  static const roleContractMetadataKey = 'personRoleContract';
  static const sourceRoleContract = 'bookmark-compat-v1';
  static const targetRoleContract = 'weblink-canonical-v1';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final PersonObjectBridge personBridge;
  final GenericDatabaseStore _genericStore;
  late final RelationTargetService _targets;
  late final RelationMutationService _mutations;

  Future<BookmarkWeblinkPersonRoleSourceSnapshot> captureSourceSnapshot(
    int workspaceId,
  ) => database.transaction(() async {
    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    );
    if (bookmarkType == null) {
      return BookmarkWeblinkPersonRoleSourceSnapshot.empty;
    }
    final bookmarkObjectIds = await _mirroredBookmarkObjectIds(workspaceId);
    if (bookmarkObjectIds.isEmpty) {
      return BookmarkWeblinkPersonRoleSourceSnapshot.empty;
    }

    final rawSourceProperties = bookmarkType.properties
        .where(
          (property) =>
              property.config[roleContractMetadataKey] == sourceRoleContract,
        )
        .toList(growable: false);
    final personType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: PersonObjectBridge.systemKey,
    );
    if (rawSourceProperties.isNotEmpty && personType == null) {
      throw StateError(
        'Managed Bookmark Person-role Relations exist without the canonical Person ObjectType.',
      );
    }
    final sourceProperties = personType == null
        ? const <String, ObjectPropertyDefinition>{}
        : _managedRoleProperties(
            bookmarkType,
            expectedContract: sourceRoleContract,
            personObjectTypeId: personType.id,
          );

    final weblinkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    ObjectPropertyDefinition? bookmarkWeblink;
    final bookmarkWeblinkMatches = bookmarkType.properties
        .where((property) => property.name == bookmarkWeblinkRelationName)
        .toList(growable: false);
    if (bookmarkWeblinkMatches.isNotEmpty) {
      if (weblinkType == null) {
        throw StateError(
          'Mirrored Bookmark Weblink Relation exists without the canonical Weblink ObjectType.',
        );
      }
      bookmarkWeblink = _requiredRelation(
        bookmarkType,
        name: bookmarkWeblinkRelationName,
        targetObjectTypeId: weblinkType.id,
        multiple: false,
      );
    }

    final objects = await objectStore.listObjects(bookmarkType.id);
    final objectsById = <int, AppObject>{
      for (final object in objects) object.id: object,
    };
    final rolesByBookmark = <int, Map<String, List<int>>>{};
    final weblinksByBookmark = <int, int?>{};
    for (final bookmarkObjectId in bookmarkObjectIds) {
      final object = objectsById[bookmarkObjectId];
      if (object == null) {
        throw StateError(
          'Bookmark compatibility mapping points to a missing Bookmark Object.',
        );
      }
      final roles = <String, List<int>>{};
      for (final entry in sourceProperties.entries) {
        final context = await _targets.selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: bookmarkObjectId,
          property: entry.value,
        );
        if (object.values.containsKey(entry.value.id)) {
          roles[entry.key] = List<int>.unmodifiable(context.selectedObjectIds);
        }
      }
      rolesByBookmark[bookmarkObjectId] = roles;

      if (bookmarkWeblink != null) {
        final context = await _targets.selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: bookmarkObjectId,
          property: bookmarkWeblink,
        );
        if (context.selectedObjectIds.length > 1) {
          throw StateError(
            'Mirrored Bookmark Weblink Relation violates single cardinality.',
          );
        }
        weblinksByBookmark[bookmarkObjectId] = context.selectedObjectIds.isEmpty
            ? null
            : context.selectedObjectIds.single;
      }
    }
    return BookmarkWeblinkPersonRoleSourceSnapshot(
      rolesByBookmark,
      weblinkObjectIdByBookmarkObjectId: weblinksByBookmark,
    );
  });

  Future<BookmarkWeblinkPersonRoleConvergenceReport> reconcileAfterWeblinkSync(
    int workspaceId, {
    BookmarkWeblinkPersonRoleSourceSnapshot? previousSource,
  }) => database.transaction(() async {
    final bookmarkObjectIds = await _mirroredBookmarkObjectIds(workspaceId);
    if (bookmarkObjectIds.isEmpty) {
      return BookmarkWeblinkPersonRoleConvergenceReport.empty;
    }

    final bookmarkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    );
    final weblinkType = await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    final personSchema = await personBridge.ensurePersonObjectType(workspaceId);
    if (bookmarkType == null || weblinkType == null) {
      throw StateError(
        'Person-role convergence requires canonical Bookmark and Weblink ObjectTypes.',
      );
    }

    final bookmarkWeblink = _requiredRelation(
      bookmarkType,
      name: bookmarkWeblinkRelationName,
      targetObjectTypeId: weblinkType.id,
      multiple: false,
    );
    final legacyRoles = await _legacyRoleState(
      workspaceId,
      bookmarkObjectIds: bookmarkObjectIds,
    );

    var refreshedBookmarkType = (await objectStore.getObjectType(
      bookmarkType.id,
    ))!;
    var refreshedWeblinkType = (await objectStore.getObjectType(
      weblinkType.id,
    ))!;
    final sourceProperties = _managedRoleProperties(
      refreshedBookmarkType,
      expectedContract: sourceRoleContract,
      personObjectTypeId: personSchema.objectType.id,
    );
    final targetProperties = _managedRoleProperties(
      refreshedWeblinkType,
      expectedContract: targetRoleContract,
      personObjectTypeId: personSchema.objectType.id,
    );
    final roles = <String>{
      ...sourceProperties.keys,
      ...targetProperties.keys,
      for (final state in legacyRoles.values) ...state.keys,
    }.toList()..sort();

    final sourcePropertyByRole = <String, ObjectPropertyDefinition>{
      ...sourceProperties,
    };
    final targetPropertyByRole = <String, ObjectPropertyDefinition>{
      ...targetProperties,
    };
    for (final role in roles) {
      if (!sourcePropertyByRole.containsKey(role)) {
        final property = await _ensureManagedRoleProperty(
          sourceType: refreshedBookmarkType,
          role: role,
          personObjectTypeId: personSchema.objectType.id,
          contract: sourceRoleContract,
          hidden: true,
        );
        sourcePropertyByRole[role] = property;
        refreshedBookmarkType = (await objectStore.getObjectType(
          bookmarkType.id,
        ))!;
      }
      if (!targetPropertyByRole.containsKey(role)) {
        final property = await _ensureManagedRoleProperty(
          sourceType: refreshedWeblinkType,
          role: role,
          personObjectTypeId: personSchema.objectType.id,
          contract: targetRoleContract,
          hidden: false,
        );
        targetPropertyByRole[role] = property;
        refreshedWeblinkType = (await objectStore.getObjectType(
          weblinkType.id,
        ))!;
      }
    }

    final bookmarkObjects = await objectStore.listObjects(bookmarkType.id);
    final bookmarkObjectsById = <int, AppObject>{
      for (final object in bookmarkObjects) object.id: object,
    };
    final sourceWrites = <_RelationWrite>[];
    for (final bookmarkObjectId in bookmarkObjectIds) {
      final object = bookmarkObjectsById[bookmarkObjectId];
      if (object == null) {
        throw StateError(
          'Bookmark compatibility mapping points to a missing Bookmark Object.',
        );
      }
      final currentRoles =
          legacyRoles[bookmarkObjectId] ?? const <String, List<int>>{};
      for (final role in roles) {
        final property = sourcePropertyByRole[role]!;
        final context = await _targets.selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: bookmarkObjectId,
          property: property,
        );
        final desired = currentRoles[role] ?? const <int>[];
        if (!object.values.containsKey(property.id) ||
            !_sameIds(context.selectedObjectIds, desired)) {
          sourceWrites.add(
            _RelationWrite(
              objectId: bookmarkObjectId,
              property: property,
              targetObjectIds: desired,
            ),
          );
        }
      }
    }
    for (final write in sourceWrites) {
      await _mutations.setRelation(
        objectId: write.objectId,
        property: write.property,
        targetObjectIds: write.targetObjectIds,
      );
    }
    for (final write in sourceWrites) {
      final verified = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: write.objectId,
        property: write.property,
      );
      if (!_sameIds(verified.selectedObjectIds, write.targetObjectIds)) {
        throw StateError(
          'Bookmark Person-role compatibility Relation verification failed.',
        );
      }
    }

    final sourcesByWeblink = <int, Map<String, _RoleSourceState>>{};
    var eligibleBookmarkCount = 0;
    for (final bookmarkObjectId in bookmarkObjectIds) {
      final weblinkContext = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: bookmarkObjectId,
        property: bookmarkWeblink,
      );
      if (weblinkContext.selectedObjectIds.isEmpty) {
        continue;
      }
      if (weblinkContext.selectedObjectIds.length != 1) {
        throw StateError(
          'Mirrored Bookmark must have exactly one canonical Weblink before Person-role convergence.',
        );
      }
      eligibleBookmarkCount += 1;
      final weblinkObjectId = weblinkContext.selectedObjectIds.single;
      final currentRoles =
          legacyRoles[bookmarkObjectId] ?? const <String, List<int>>{};
      final states = sourcesByWeblink.putIfAbsent(
        weblinkObjectId,
        () => <String, _RoleSourceState>{},
      );
      for (final role in roles) {
        final current = List<int>.unmodifiable(
          currentRoles[role] ?? const <int>[],
        );
        final previous =
            previousSource?.wasLinkedTo(bookmarkObjectId, weblinkObjectId) ==
                true
            ? previousSource?.personIdsFor(bookmarkObjectId, role)
            : null;
        final existing = states[role];
        if (existing == null) {
          states[role] = _RoleSourceState(
            currentPersonIds: current,
            previousPersonIds: previous,
            previousComplete: previous != null,
          );
          continue;
        }
        if (!_sameIds(existing.currentPersonIds, current)) {
          throw StateError(
            'Multiple Bookmarks for one Weblink have conflicting Person-role Relations.',
          );
        }
        existing.addPrevious(previous, sameIds: _sameIds);
      }
    }

    if (sourcesByWeblink.isEmpty) {
      return BookmarkWeblinkPersonRoleConvergenceReport.empty;
    }

    final weblinkObjects = await objectStore.listObjects(weblinkType.id);
    final weblinkObjectsById = <int, AppObject>{
      for (final object in weblinkObjects) object.id: object,
    };
    final targetWrites = <_RelationWrite>[];
    var unchangedCount = 0;
    final mutatedWeblinkIds = <int>{};
    for (final weblinkEntry in sourcesByWeblink.entries) {
      final targetObject = weblinkObjectsById[weblinkEntry.key];
      if (targetObject == null) {
        throw StateError('Canonical Weblink target does not exist.');
      }
      var weblinkChanged = false;
      var weblinkUnchanged = true;
      for (final role in roles) {
        final property = targetPropertyByRole[role]!;
        final source = weblinkEntry.value[role]!;
        final context = await _targets.selectionForMutation(
          workspaceId: workspaceId,
          sourceObjectId: weblinkEntry.key,
          property: property,
        );
        final targetInitialized = targetObject.values.containsKey(property.id);
        final currentTarget = context.selectedObjectIds;
        if (targetInitialized &&
            _sameIds(currentTarget, source.currentPersonIds)) {
          continue;
        }

        if (!targetInitialized) {
          targetWrites.add(
            _RelationWrite(
              objectId: weblinkEntry.key,
              property: property,
              targetObjectIds: source.currentPersonIds,
            ),
          );
          weblinkChanged = true;
          weblinkUnchanged = false;
          continue;
        }

        final previous = source.previousComplete
            ? source.previousPersonIds
            : null;
        if (previous == null) {
          throw StateError(
            'Canonical Weblink already has conflicting Person-role state without a complete compatibility checkpoint.',
          );
        }
        final sourceChanged = !_sameIds(source.currentPersonIds, previous);
        final targetStillPrevious = _sameIds(currentTarget, previous);
        if (sourceChanged && targetStillPrevious) {
          targetWrites.add(
            _RelationWrite(
              objectId: weblinkEntry.key,
              property: property,
              targetObjectIds: source.currentPersonIds,
            ),
          );
          weblinkChanged = true;
          weblinkUnchanged = false;
          continue;
        }
        if (!sourceChanged && !targetStillPrevious) {
          // Canonical-only Person-role edits are first-class Object state.
          // Preserve them while the compatibility source remains unchanged.
          continue;
        }
        throw StateError(
          'Legacy Bookmark Person roles and canonical Weblink Person roles changed independently; refusing to choose an authority.',
        );
      }
      if (weblinkChanged) mutatedWeblinkIds.add(weblinkEntry.key);
      if (weblinkUnchanged) unchangedCount += 1;
    }

    for (final write in targetWrites) {
      await _mutations.setRelation(
        objectId: write.objectId,
        property: write.property,
        targetObjectIds: write.targetObjectIds,
      );
    }
    for (final write in targetWrites) {
      final verified = await _targets.selectionForMutation(
        workspaceId: workspaceId,
        sourceObjectId: write.objectId,
        property: write.property,
      );
      if (!_sameIds(verified.selectedObjectIds, write.targetObjectIds)) {
        throw StateError(
          'Canonical Weblink Person-role Relation verification failed after convergence.',
        );
      }
    }

    final sortedMutatedIds = mutatedWeblinkIds.toList()..sort();
    return BookmarkWeblinkPersonRoleConvergenceReport(
      bookmarkCount: eligibleBookmarkCount,
      weblinkCount: sourcesByWeblink.length,
      roleCount: roles.length,
      convergedWeblinkCount: sortedMutatedIds.length,
      unchangedWeblinkCount: unchangedCount,
      mutatedWeblinkObjectIds: List<int>.unmodifiable(sortedMutatedIds),
    );
  });

  Future<Map<int, Map<String, List<int>>>> _legacyRoleState(
    int workspaceId, {
    required List<int> bookmarkObjectIds,
  }) async {
    final rows = await database
        .customSelect(
          '''SELECT bol.object_id AS bookmark_object_id,
                bp.person_id AS person_id,
                bp.role AS role
         FROM bookmark_object_links bol
         INNER JOIN bookmark_workspace bw
           ON bw.bookmark_id = bol.bookmark_id
          AND bw.workspace_id = bol.workspace_id
         INNER JOIN bookmark_people bp ON bp.bookmark_id = bol.bookmark_id
         WHERE bol.workspace_id = ?
         ORDER BY bol.bookmark_id, bp.person_id, bp.role''',
          variables: [Variable<int>(workspaceId)],
        )
        .get();
    final bookmarkSet = bookmarkObjectIds.toSet();
    final result = <int, Map<String, List<int>>>{
      for (final objectId in bookmarkObjectIds) objectId: <String, List<int>>{},
    };
    for (final row in rows) {
      final bookmarkObjectId = row.read<int>('bookmark_object_id');
      if (!bookmarkSet.contains(bookmarkObjectId)) {
        throw StateError(
          'Legacy Person-role row resolved outside the current Bookmark compatibility set.',
        );
      }
      final role = normalizePersonRole(row.read<String>('role'));
      final legacyPersonId = row.read<int>('person_id');
      final personObjectId = await personBridge.objectIdForLegacyPerson(
        workspaceId,
        legacyPersonId,
      );
      if (personObjectId == null) {
        throw StateError(
          'Legacy Bookmark Person role has no canonical Person Object identity.',
        );
      }
      final ids = result[bookmarkObjectId]!.putIfAbsent(role, () => <int>[]);
      if (!ids.contains(personObjectId)) ids.add(personObjectId);
    }
    return result;
  }

  Map<String, ObjectPropertyDefinition> _managedRoleProperties(
    AppObjectType sourceType, {
    required String expectedContract,
    required int personObjectTypeId,
  }) {
    final result = <String, ObjectPropertyDefinition>{};
    for (final property in sourceType.properties) {
      if (property.config[roleContractMetadataKey] != expectedContract) {
        continue;
      }
      final rawRole = property.config[roleMetadataKey];
      if (rawRole is! String ||
          rawRole.isEmpty ||
          normalizePersonRole(rawRole) != rawRole) {
        throw StateError(
          'Managed Person-role Relation has invalid role metadata.',
        );
      }
      final hasManagedPairMetadata =
          property.config.containsKey('bidirectional') ||
          property.config.containsKey('inversePropertyId') ||
          property.config.containsKey('pairRole');
      if (!property.isRelation ||
          property.targetObjectTypeId != personObjectTypeId ||
          !property.allowsMultipleRelations ||
          hasManagedPairMetadata) {
        throw StateError(
          'Managed Person-role Property does not match the required canonical Relation schema.',
        );
      }
      if (result.containsKey(rawRole)) {
        throw StateError(
          'Duplicate managed Person-role Properties claim the same role.',
        );
      }
      result[rawRole] = property;
    }
    return result;
  }

  Future<ObjectPropertyDefinition> _ensureManagedRoleProperty({
    required AppObjectType sourceType,
    required String role,
    required int personObjectTypeId,
    required String contract,
    required bool hidden,
  }) async {
    final current = (await objectStore.getObjectType(sourceType.id))!;
    final existing = _managedRoleProperties(
      current,
      expectedContract: contract,
      personObjectTypeId: personObjectTypeId,
    )[role];
    if (existing != null) return existing;

    final name = _availableRolePropertyName(current, role);
    final id = await objectStore.createRelationProperty(
      objectTypeId: current.id,
      name: name,
      targetObjectTypeId: personObjectTypeId,
      multiple: true,
      metadata: <String, dynamic>{
        'system': true,
        if (hidden) 'hidden': true,
        roleMetadataKey: role,
        roleContractMetadataKey: contract,
      },
      allowSystemMutation: true,
    );
    final refreshed = (await objectStore.getObjectType(current.id))!;
    final property = refreshed.properties.firstWhere(
      (candidate) => candidate.id == id,
    );
    final validated = _managedRoleProperties(
      refreshed,
      expectedContract: contract,
      personObjectTypeId: personObjectTypeId,
    )[role];
    if (validated?.id != property.id) {
      throw StateError('Managed Person-role Property creation was ambiguous.');
    }
    return property;
  }

  String _availableRolePropertyName(AppObjectType type, String role) {
    final names = type.properties.map((property) => property.name).toSet();
    if (!names.contains(role)) return role;
    final base = '$role (人物)';
    if (!names.contains(base)) return base;
    var suffix = 2;
    while (names.contains('$base $suffix')) {
      suffix += 1;
    }
    return '$base $suffix';
  }

  Future<List<int>> _mirroredBookmarkObjectIds(int workspaceId) async {
    final rows = await database
        .customSelect(
          '''SELECT bol.object_id
         FROM bookmark_object_links bol
         INNER JOIN bookmark_workspace bw
           ON bw.bookmark_id = bol.bookmark_id
          AND bw.workspace_id = bol.workspace_id
         WHERE bol.workspace_id = ?
         ORDER BY bol.bookmark_id''',
          variables: [Variable<int>(workspaceId)],
        )
        .get();
    return rows
        .map((row) => row.read<int>('object_id'))
        .toList(growable: false);
  }

  ObjectPropertyDefinition _requiredRelation(
    AppObjectType sourceType, {
    required String name,
    required int targetObjectTypeId,
    required bool multiple,
  }) {
    final matches = sourceType.properties
        .where((property) => property.name == name)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError(
        'Canonical ${sourceType.name} ObjectType must contain exactly one "$name" Relation.',
      );
    }
    final property = matches.single;
    if (!property.isRelation ||
        property.targetObjectTypeId != targetObjectTypeId ||
        property.allowsMultipleRelations != multiple) {
      throw StateError(
        'Canonical ${sourceType.name} "$name" does not match the required Relation schema.',
      );
    }
    return property;
  }

  bool _sameIds(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class _RoleSourceState {
  _RoleSourceState({
    required this.currentPersonIds,
    required this.previousPersonIds,
    required this.previousComplete,
  });

  final List<int> currentPersonIds;
  List<int>? previousPersonIds;
  bool previousComplete;

  void addPrevious(
    List<int>? candidate, {
    required bool Function(List<int>, List<int>) sameIds,
  }) {
    if (!previousComplete) return;
    final previous = previousPersonIds;
    if (candidate == null ||
        previous == null ||
        !sameIds(previous, candidate)) {
      previousComplete = false;
      previousPersonIds = null;
    }
  }
}

class _RelationWrite {
  const _RelationWrite({
    required this.objectId,
    required this.property,
    required this.targetObjectIds,
  });

  final int objectId;
  final ObjectPropertyDefinition property;
  final List<int> targetObjectIds;
}
