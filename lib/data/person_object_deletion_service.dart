import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'person_object_bridge.dart';
import 'relation_mutation_service.dart';
import 'system_object_store.dart';

/// Compatibility preflight/cleanup for canonical Person Object deletion.
///
/// The canonical Object remains the identity authority. Legacy `people` rows
/// survive only as temporary projections for People UI, Bookmark roles/groups,
/// saved-view filters, and old Vault compatibility. A mapped legacy row must be
/// deleted in the same transaction as the canonical Object so a later
/// reconciliation cannot recreate an explicitly deleted Person.
class PersonObjectDeletionCompatibility {
  const PersonObjectDeletionCompatibility({
    required this.database,
    required this.objectStore,
    required this.personBridge,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final PersonObjectBridge personBridge;

  /// Returns the legacy Person represented by [objectId], or null when the
  /// canonical Person has no legacy projection.
  ///
  /// A missing link row is recoverable only when the canonical identity-managed
  /// `Legacy Person ID` claim is valid and unambiguous. The existing bridge owns
  /// that reconciliation and fails closed on duplicate/damaged claims.
  ///
  /// When a surviving legacy Saved View still filters by the Person, deletion
  /// also fails closed here before canonical Relation detach/Object deletion.
  /// The current legacy FK would otherwise turn that filter into null, which
  /// means “no Person filter” and silently broadens the View semantics.
  Future<int?> legacyPersonIdForCanonicalDeletion({
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
  }) async {
    final schema = await personBridge.ensurePersonObjectType(workspaceId);
    if (schema.objectType.id != objectTypeId) return null;

    final matches = (await objectStore.listObjects(objectTypeId))
        .where((object) => object.id == objectId)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError(
        'Canonical Person deletion target is missing or belongs to another ObjectType.',
      );
    }

    final mapped = await personBridge.legacyPersonIdForObject(
      workspaceId,
      objectId,
    );
    if (mapped != null) {
      await _assertNoSavedViewReference(mapped);
      return mapped;
    }

    final rawLegacyId = matches.single.values[schema.legacyPersonIdProperty.id];
    if (rawLegacyId == null) return null;
    final claimedLegacyId = _positiveInt(rawLegacyId);
    if (claimedLegacyId == null) {
      throw StateError(
        'Canonical Person has a malformed Legacy Person ID; refusing deletion.',
      );
    }

    final legacyRows = await (database.select(
      database.people,
    )..where((person) => person.id.equals(claimedLegacyId))).get();
    if (legacyRows.length != 1) {
      throw StateError(
        'Canonical Person claims a missing legacy Person identity; refusing deletion.',
      );
    }

    // Reuse the canonical bridge instead of inventing a second mapping repair
    // path. When the claim is ambiguous or conflicts with another mapping this
    // throws before deletion. Callers run this inside the outer delete
    // transaction, so any incidental compatibility projection is rolled back if
    // the later Relation-safe deletion fails.
    await personBridge.syncLegacyPeople(workspaceId);
    final recovered = await personBridge.legacyPersonIdForObject(
      workspaceId,
      objectId,
    );
    if (recovered == null || recovered != claimedLegacyId) {
      throw StateError(
        'Canonical Person identity mapping could not be recovered safely.',
      );
    }
    await _assertNoSavedViewReference(recovered);
    return recovered;
  }

  Future<void> _assertNoSavedViewReference(int personId) async {
    final references = await (database.select(
      database.savedViews,
    )..where((view) => view.personFilterId.equals(personId))).get();
    if (references.isNotEmpty) {
      throw StateError(
        'Person is still referenced by a Saved View; refusing deletion to preserve the filter.',
      );
    }
  }

  /// Removes the temporary legacy Person projection.
  ///
  /// Existing foreign-key actions intentionally preserve legacy semantics while
  /// those callers survive: Bookmark role assignments and PersonGroup
  /// memberships cascade, and the transition-only `person_object_links` row
  /// cascades as well. Saved View Person filters are preflighted above and may
  /// never be cleared implicitly by this deletion path.
  Future<void> deleteLegacyCompatibilityRow(int personId) async {
    if (personId <= 0) {
      throw ArgumentError.value(
        personId,
        'personId',
        'Person id must be positive.',
      );
    }
    final deleted = await (database.delete(
      database.people,
    )..where((person) => person.id.equals(personId))).go();
    if (deleted != 1) {
      throw StateError(
        'Legacy Person projection is missing; refusing a partial Person deletion.',
      );
    }
  }

  int? _positiveInt(Object value) {
    if (value is int) return value > 0 ? value : null;
    if (value is num) {
      if (!value.isFinite) return null;
      final parsed = value.toInt();
      return parsed > 0 && value == parsed ? parsed : null;
    }
    final parsed = int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

/// Canonical lifecycle boundary for deleting a Person from a legacy Person id.
///
/// Normal legacy People UI can continue passing its compatibility [personId],
/// but deletion authority is the canonical generic Person Object. Incoming
/// Relations are detached through [RelationMutationService] before the Object
/// and its legacy projection disappear atomically.
class PersonObjectDeletionService {
  PersonObjectDeletionService({
    required this.database,
    required this.personBridge,
    required this.relationMutations,
    required this.compatibility,
  });

  factory PersonObjectDeletionService.forDatabase(AppDatabase database) {
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    return PersonObjectDeletionService(
      database: database,
      personBridge: bridge,
      relationMutations: RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
        genericStore: genericStore,
      ),
      compatibility: PersonObjectDeletionCompatibility(
        database: database,
        objectStore: objectStore,
        personBridge: bridge,
      ),
    );
  }

  final AppDatabase database;
  final PersonObjectBridge personBridge;
  final RelationMutationService relationMutations;
  final PersonObjectDeletionCompatibility compatibility;

  Future<void> delete({required int workspaceId, required int personId}) async {
    await deleteWithImpact(workspaceId: workspaceId, personId: personId);
  }

  /// Deletes one canonical Person and returns the exact committed Relation
  /// deletion impact for downstream derived projections.
  ///
  /// The impact is returned only after the outer Person + compatibility
  /// transaction commits. Callers that do not own a derived projection can keep
  /// using [delete].
  Future<RelationObjectDeletionImpact> deleteWithImpact({
    required int workspaceId,
    required int personId,
  }) {
    return database.transaction(() async {
      final legacyRows = await (database.select(
        database.people,
      )..where((person) => person.id.equals(personId))).get();
      if (legacyRows.length != 1) {
        throw ArgumentError.value(
          personId,
          'personId',
          'Legacy Person does not exist.',
        );
      }

      var objectId = await personBridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      );
      if (objectId == null) {
        await personBridge.syncLegacyPeople(workspaceId);
        objectId = await personBridge.objectIdForLegacyPerson(
          workspaceId,
          personId,
        );
      }
      if (objectId == null) {
        throw StateError(
          'Legacy Person has no canonical Person Object mapping.',
        );
      }

      final schema = await personBridge.ensurePersonObjectType(workspaceId);
      final resolvedLegacyPersonId = await compatibility
          .legacyPersonIdForCanonicalDeletion(
            workspaceId: workspaceId,
            objectTypeId: schema.objectType.id,
            objectId: objectId,
          );
      if (resolvedLegacyPersonId != personId) {
        throw StateError(
          'Canonical Person identity does not match the requested legacy Person.',
        );
      }

      final impact = await relationMutations.deleteObjectWithImpact(
        workspaceId: workspaceId,
        objectTypeId: schema.objectType.id,
        objectId: objectId,
      );
      await compatibility.deleteLegacyCompatibilityRow(personId);
      return impact;
    });
  }
}
