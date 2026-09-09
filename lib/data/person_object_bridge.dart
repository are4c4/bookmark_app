import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'object_store.dart';
import 'system_object_store.dart';

class PersonObjectSchema {
  const PersonObjectSchema({
    required this.objectType,
    required this.legacyPersonIdProperty,
    required this.noteProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition legacyPersonIdProperty;
  final ObjectPropertyDefinition noteProperty;
}

class _ResolvedPersonObject {
  const _ResolvedPersonObject({
    required this.objectId,
    required this.seedFromLegacy,
  });

  final int objectId;
  final bool seedFromLegacy;
}

/// Compatibility bridge between legacy People rows and canonical Person Objects.
///
/// Legacy rows may seed a Person Object once while no canonical identity exists.
/// After a stable mapping exists, the generic Person Object is authoritative and
/// this bridge only projects its title/Note back into `people` for compatibility
/// with surviving legacy UI, role/group storage, and old Vaults.
class PersonObjectBridge {
  PersonObjectBridge({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
  });

  static const systemKey = 'person';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??= database.transaction(() async {
        await systemObjectStore.ensureSchema();
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS person_object_links (
            workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
            person_id INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
            object_id INTEGER NOT NULL REFERENCES generic_records(id) ON DELETE CASCADE,
            PRIMARY KEY(workspace_id, person_id),
            UNIQUE(workspace_id, object_id)
          )
        ''');
      });

  Future<PersonObjectSchema> ensurePersonObjectType(int workspaceId) async {
    await ensureSchema();
    final type = await systemObjectStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
      name: '人物',
      icon: '👤',
    );
    _assertExistingPropertyCompatible(
      type: type,
      name: 'Legacy Person ID',
      matches: _isCanonicalLegacyIdProperty,
    );
    _assertExistingPropertyCompatible(
      type: type,
      name: 'Note',
      matches: (property) => property.type == ObjectPropertyType.text,
    );

    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Person ID',
      type: ObjectPropertyType.number,
      config: const <String, dynamic>{
        'system': true,
        'hidden': true,
        ObjectPropertyDefinition.identityManagedConfigKey: true,
      },
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Note',
      type: ObjectPropertyType.text,
    );

    final refreshed = (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;
    final legacyId = _requiredProperty(refreshed, 'Legacy Person ID');
    final note = _requiredProperty(refreshed, 'Note');
    if (!_isCanonicalLegacyIdProperty(legacyId)) {
      throw StateError(
        'Existing system Property "Legacy Person ID" does not match the required Person identity schema.',
      );
    }
    if (note.type != ObjectPropertyType.text) {
      throw StateError(
        'Existing system Property "Note" does not match the required Person schema.',
      );
    }
    return PersonObjectSchema(
      objectType: refreshed,
      legacyPersonIdProperty: legacyId,
      noteProperty: note,
    );
  }

  /// Reconciles legacy People with canonical Person Objects and returns the
  /// canonical ids visited by this pass.
  ///
  /// A legacy row seeds title/Note only when no canonical Person identity exists.
  /// Once mapped, canonical state wins. Compatibility projection is skipped when
  /// already equal so the People watcher cannot create a no-op sync loop.
  Future<List<int>> syncLegacyPeople(int workspaceId) async {
    final schema = await ensurePersonObjectType(workspaceId);
    return database.transaction(() async {
      final people = await database.select(database.people).get();
      final touched = <int>[];
      for (final person in people) {
        final resolved = await _ensureObjectForPerson(
          workspaceId: workspaceId,
          schema: schema,
          person: person,
        );
        if (resolved.seedFromLegacy) {
          await objectStore.setPropertyValue(
            objectId: resolved.objectId,
            property: schema.noteProperty,
            value: person.note,
          );
        }
        final object = await _canonicalPersonObject(
          schema: schema,
          objectId: resolved.objectId,
        );
        await _projectCanonicalToLegacy(
          person: person,
          object: object,
          noteProperty: schema.noteProperty,
        );
        touched.add(resolved.objectId);
      }
      touched.sort();
      return List<int>.unmodifiable(touched);
    });
  }

  Future<int?> objectIdForLegacyPerson(int workspaceId, int personId) async {
    final schema = await ensurePersonObjectType(workspaceId);
    final row = await database.customSelect(
      '''SELECT object_id FROM person_object_links
         WHERE workspace_id = ? AND person_id = ? LIMIT 1''',
      variables: [Variable<int>(workspaceId), Variable<int>(personId)],
    ).getSingleOrNull();
    if (row == null) return null;
    final objectId = row.read<int>('object_id');
    await _validateMappedObject(
      workspaceId: workspaceId,
      schema: schema,
      personId: personId,
      objectId: objectId,
    );
    return objectId;
  }

  Future<int?> legacyPersonIdForObject(int workspaceId, int objectId) async {
    final schema = await ensurePersonObjectType(workspaceId);
    final row = await database.customSelect(
      '''SELECT person_id FROM person_object_links
         WHERE workspace_id = ? AND object_id = ? LIMIT 1''',
      variables: [Variable<int>(workspaceId), Variable<int>(objectId)],
    ).getSingleOrNull();
    if (row == null) return null;
    final personId = row.read<int>('person_id');
    await _validateMappedObject(
      workspaceId: workspaceId,
      schema: schema,
      personId: personId,
      objectId: objectId,
    );
    return personId;
  }

  Future<_ResolvedPersonObject> _ensureObjectForPerson({
    required int workspaceId,
    required PersonObjectSchema schema,
    required Person person,
  }) async {
    final linkedRow = await database.customSelect(
      '''SELECT object_id FROM person_object_links
         WHERE workspace_id = ? AND person_id = ? LIMIT 1''',
      variables: [Variable<int>(workspaceId), Variable<int>(person.id)],
    ).getSingleOrNull();
    if (linkedRow != null) {
      final objectId = linkedRow.read<int>('object_id');
      await _validateMappedObject(
        workspaceId: workspaceId,
        schema: schema,
        personId: person.id,
        objectId: objectId,
      );
      return _ResolvedPersonObject(objectId: objectId, seedFromLegacy: false);
    }

    final matchingObjects = (await objectStore.listObjects(schema.objectType.id))
        .where(
          (object) =>
              _legacyId(object.values[schema.legacyPersonIdProperty.id]) ==
              person.id,
        )
        .toList(growable: false);
    if (matchingObjects.length > 1) {
      throw StateError(
        'Legacy Person identity is ambiguous; multiple canonical Person Objects claim the same legacy id.',
      );
    }
    if (matchingObjects.length == 1) {
      final objectId = matchingObjects.single.id;
      await _insertMapping(
        workspaceId: workspaceId,
        personId: person.id,
        objectId: objectId,
      );
      return _ResolvedPersonObject(objectId: objectId, seedFromLegacy: false);
    }

    final objectId = await objectStore.createObject(
      objectTypeId: schema.objectType.id,
      title: person.name,
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: schema.legacyPersonIdProperty,
      value: person.id,
    );
    await _insertMapping(
      workspaceId: workspaceId,
      personId: person.id,
      objectId: objectId,
    );
    return _ResolvedPersonObject(objectId: objectId, seedFromLegacy: true);
  }

  Future<AppObject> _canonicalPersonObject({
    required PersonObjectSchema schema,
    required int objectId,
  }) async {
    final matches = (await objectStore.listObjects(schema.objectType.id))
        .where((object) => object.id == objectId)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError(
        'Canonical Person mapping points to a missing or wrong-type Object.',
      );
    }
    return matches.single;
  }

  Future<void> _projectCanonicalToLegacy({
    required Person person,
    required AppObject object,
    required ObjectPropertyDefinition noteProperty,
  }) async {
    final canonicalName = object.title.trim();
    if (canonicalName.isEmpty) {
      throw StateError(
        'Canonical Person title is empty; refusing an invalid legacy projection.',
      );
    }
    final rawNote = object.values[noteProperty.id];
    if (rawNote != null && rawNote is! String) {
      throw StateError(
        'Canonical Person Note is malformed; refusing an invalid legacy projection.',
      );
    }
    final canonicalNote = rawNote as String?;
    if (person.name == canonicalName && person.note == canonicalNote) return;

    try {
      final changed =
          await (database.update(
            database.people,
          )..where((row) => row.id.equals(person.id))).write(
            PeopleCompanion(
              name: Value(canonicalName),
              note: Value(canonicalNote),
            ),
          );
      if (changed != 1) {
        throw StateError(
          'Legacy Person projection disappeared during canonical reconciliation.',
        );
      }
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
        'Canonical Person cannot be projected to legacy People without a conflict.',
      );
    }
  }

  Future<void> _insertMapping({
    required int workspaceId,
    required int personId,
    required int objectId,
  }) async {
    try {
      await database.customStatement(
        '''INSERT INTO person_object_links(workspace_id, person_id, object_id)
           VALUES (?, ?, ?)''',
        [workspaceId, personId, objectId],
      );
    } catch (_) {
      throw StateError(
        'Canonical Person identity mapping is inconsistent; refusing to replace it.',
      );
    }
  }

  Future<void> _validateMappedObject({
    required int workspaceId,
    required PersonObjectSchema schema,
    required int personId,
    required int objectId,
  }) async {
    final object = (await objectStore.listObjects(schema.objectType.id))
        .where((candidate) => candidate.id == objectId)
        .toList(growable: false);
    if (object.length != 1) {
      throw StateError(
        'Canonical Person mapping points to a missing or wrong-type Object.',
      );
    }
    if (schema.objectType.workspaceId != workspaceId ||
        _legacyId(
              object.single.values[schema.legacyPersonIdProperty.id],
            ) !=
            personId) {
      throw StateError(
        'Canonical Person mapping does not match the persisted Person identity.',
      );
    }
  }

  void _assertExistingPropertyCompatible({
    required AppObjectType type,
    required String name,
    required bool Function(ObjectPropertyDefinition property) matches,
  }) {
    final existing = type.properties
        .where((property) => property.name == name)
        .toList(growable: false);
    if (existing.isEmpty) return;
    if (existing.length != 1 || !matches(existing.single)) {
      throw StateError(
        'Existing system Property "$name" does not match the required Person schema.',
      );
    }
  }

  bool _isCanonicalLegacyIdProperty(ObjectPropertyDefinition property) =>
      property.type == ObjectPropertyType.number &&
      property.config['system'] == true &&
      property.config['hidden'] == true &&
      property.isIdentityManaged;

  ObjectPropertyDefinition _requiredProperty(AppObjectType type, String name) {
    final matches = type.properties
        .where((property) => property.name == name)
        .toList(growable: false);
    if (matches.length != 1) {
      throw StateError(
        'Canonical Person ObjectType must contain exactly one "$name" Property.',
      );
    }
    return matches.single;
  }

  int? _legacyId(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse('$value');
  }
}
