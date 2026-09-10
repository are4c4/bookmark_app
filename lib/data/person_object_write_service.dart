import 'package:drift/drift.dart';

import 'app_database.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'person_object_bridge.dart';
import 'system_object_store.dart';

class PersonCommittedWriteImpact {
  const PersonCommittedWriteImpact({
    required this.legacyPersonId,
    required this.canonicalObjectId,
    required this.canonicalMutationCommitted,
  });

  final int legacyPersonId;
  final int canonicalObjectId;
  final bool canonicalMutationCommitted;
}

/// Canonical Object-first create/update boundary for Person writes.
///
/// The generic Person Object is mutated before the legacy `people` projection
/// inside one database transaction. Legacy rows remain present for compatibility
/// with People UI, Bookmark role/group storage, and old Vaults during migration.
class PersonObjectWriteService {
  PersonObjectWriteService({
    required this.database,
    required this.objectStore,
    required this.personBridge,
  });

  factory PersonObjectWriteService.forDatabase(AppDatabase database) {
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjectStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    return PersonObjectWriteService(
      database: database,
      objectStore: objectStore,
      personBridge: PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjectStore,
      ),
    );
  }

  final AppDatabase database;
  final ObjectStore objectStore;
  final PersonObjectBridge personBridge;

  Future<int> create({
    required int workspaceId,
    required String name,
    String? note,
  }) async {
    final result = await createWithImpact(
      workspaceId: workspaceId,
      name: name,
      note: note,
    );
    return result.legacyPersonId;
  }

  Future<PersonCommittedWriteImpact> createWithImpact({
    required int workspaceId,
    required String name,
    String? note,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Person name is empty');
    }
    final normalizedNote = _normalizedNote(note);

    final existing = await (database.select(
      database.people,
    )..where((person) => person.name.equals(trimmedName))).getSingleOrNull();
    if (existing != null) {
      final objectIdBeforeSync = await personBridge.objectIdForLegacyPerson(
        workspaceId,
        existing.id,
      );
      await personBridge.syncLegacyPeople(workspaceId);
      final canonicalObjectId = await personBridge.objectIdForLegacyPerson(
        workspaceId,
        existing.id,
      );
      if (canonicalObjectId == null) {
        throw StateError(
          'Legacy Person has no canonical Person Object mapping after sync.',
        );
      }
      if (normalizedNote != null) {
        final updateImpact = await updateWithImpact(
          workspaceId: workspaceId,
          personId: existing.id,
          name: existing.name,
          note: normalizedNote,
        );
        if (updateImpact == null) {
          throw StateError('Expected committed Person update impact.');
        }
        return updateImpact;
      }
      return PersonCommittedWriteImpact(
        legacyPersonId: existing.id,
        canonicalObjectId: canonicalObjectId,
        canonicalMutationCommitted: objectIdBeforeSync == null,
      );
    }

    final schema = await personBridge.ensurePersonObjectType(workspaceId);
    await personBridge.ensureSchema();
    return database.transaction(() async {
      final objectId = await objectStore.createObject(
        objectTypeId: schema.objectType.id,
        title: trimmedName,
      );
      if (normalizedNote != null) {
        await objectStore.setPropertyValue(
          objectId: objectId,
          property: schema.noteProperty,
          value: normalizedNote,
        );
      }

      final personId = await database
          .into(database.people)
          .insert(
            PeopleCompanion.insert(
              name: trimmedName,
              note: Value(normalizedNote),
            ),
          );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: schema.legacyPersonIdProperty,
        value: personId,
      );
      await database.customStatement(
        '''INSERT INTO person_object_links(workspace_id, person_id, object_id)
           VALUES (?, ?, ?)''',
        <Object>[workspaceId, personId, objectId],
      );
      return PersonCommittedWriteImpact(
        legacyPersonId: personId,
        canonicalObjectId: objectId,
        canonicalMutationCommitted: true,
      );
    });
  }

  Future<void> update({
    required int workspaceId,
    required int personId,
    required String name,
    String? note,
  }) async {
    await updateWithImpact(
      workspaceId: workspaceId,
      personId: personId,
      name: name,
      note: note,
    );
  }

  Future<PersonCommittedWriteImpact?> updateWithImpact({
    required int workspaceId,
    required int personId,
    required String name,
    String? note,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;
    final normalizedNote = _normalizedNote(note);

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
      throw StateError('Legacy Person has no canonical Person Object mapping.');
    }
    final canonicalObjectId = objectId;

    final schema = await personBridge.ensurePersonObjectType(workspaceId);
    return database.transaction(() async {
      await objectStore.renameObject(canonicalObjectId, trimmedName);
      await objectStore.setPropertyValue(
        objectId: canonicalObjectId,
        property: schema.noteProperty,
        value: normalizedNote,
      );
      final changed =
          await (database.update(
            database.people,
          )..where((person) => person.id.equals(personId))).write(
            PeopleCompanion(
              name: Value(trimmedName),
              note: Value(normalizedNote),
            ),
          );
      if (changed != 1) {
        throw StateError(
          'Legacy Person projection is missing; refusing a partial Person write.',
        );
      }
      return PersonCommittedWriteImpact(
        legacyPersonId: personId,
        canonicalObjectId: canonicalObjectId,
        canonicalMutationCommitted: true,
      );
    });
  }

  String? _normalizedNote(String? note) {
    final trimmed = note?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
