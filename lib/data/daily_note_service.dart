import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';
import 'system_object_store.dart';

class DailyNoteDefinition {
  const DailyNoteDefinition({
    required this.objectType,
    required this.dateProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition dateProperty;
}

/// Daily Notes are normal Objects keyed by one local calendar date.
///
/// The registry provides uniqueness/open-or-create semantics without turning
/// Daily Note content into a separate silo. Properties, Body, Relations and
/// future embedded Views continue to use the general Object mechanisms.
class DailyNoteService {
  DailyNoteService({
    required this.genericStore,
    required this.objectStore,
    required this.systemObjects,
    required this.defaultsStore,
  });

  static const String systemKey = 'dailyNote';

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;
  final ObjectTypeDefaultsStore defaultsStore;
  Future<void>? _registryReady;

  Future<void> ensureRegistry() => _registryReady ??=
      genericStore.database.transaction(() async {
        await genericStore.ensureSchema();
        await genericStore.database.customStatement('''
          CREATE TABLE IF NOT EXISTS daily_note_registry (
            workspace_id INTEGER NOT NULL
              REFERENCES workspaces(id) ON DELETE CASCADE,
            note_date TEXT NOT NULL,
            object_id INTEGER NOT NULL UNIQUE
              REFERENCES generic_records(id) ON DELETE CASCADE,
            PRIMARY KEY(workspace_id, note_date)
          )
        ''');
      });

  Future<DailyNoteDefinition> ensureDefinition(int workspaceId) async {
    var type = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
      name: 'Daily Note',
      icon: '📅',
    );
    final dateProperty = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Date',
      type: ObjectPropertyType.date,
    );
    type = (await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;

    final currentDefaults = await defaultsStore.read(type.id);
    if (currentDefaults == null) {
      await defaultsStore.write(
        objectTypeId: type.id,
        defaults: ObjectTypeDefaults(
          visiblePropertyIds: <int>[dateProperty.id],
          propertyOrder: <int>[dateProperty.id],
          openMode: ObjectOpenMode.fullPage,
        ),
      );
    }

    return DailyNoteDefinition(objectType: type, dateProperty: dateProperty);
  }

  Future<AppObject> openOrCreate({
    required int workspaceId,
    DateTime? date,
  }) async {
    await ensureRegistry();
    final definition = await ensureDefinition(workspaceId);
    final dateKey = _dateKey((date ?? DateTime.now()).toLocal());

    final registered = await _registeredObject(
      workspaceId: workspaceId,
      dateKey: dateKey,
      objectTypeId: definition.objectType.id,
    );
    if (registered != null) return registered;

    // Adopt a matching Object that predates the registry before creating a new
    // one. This keeps the migration path backward-compatible.
    final existingObjects = await objectStore.listObjects(definition.objectType.id);
    for (final object in existingObjects) {
      if ('${object.values[definition.dateProperty.id] ?? ''}' == dateKey) {
        await _register(
          workspaceId: workspaceId,
          dateKey: dateKey,
          objectId: object.id,
        );
        return object;
      }
    }

    final createdId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: dateKey,
    );
    await objectStore.setPropertyValue(
      objectId: createdId,
      property: definition.dateProperty,
      value: dateKey,
    );
    await _register(
      workspaceId: workspaceId,
      dateKey: dateKey,
      objectId: createdId,
    );

    final winner = await _registeredObject(
      workspaceId: workspaceId,
      dateKey: dateKey,
      objectTypeId: definition.objectType.id,
    );
    if (winner == null) {
      throw StateError('Daily Note registry did not retain an Object.');
    }
    if (winner.id != createdId) {
      // Another caller won the same-date registration. Remove only the
      // duplicate Object created by this call.
      await objectStore.deleteObject(createdId);
    }
    return winner;
  }

  Future<void> _register({
    required int workspaceId,
    required String dateKey,
    required int objectId,
  }) async {
    await genericStore.database.customStatement(
      '''INSERT OR IGNORE INTO daily_note_registry(workspace_id, note_date, object_id)
         VALUES (?, ?, ?)''',
      [workspaceId, dateKey, objectId],
    );
  }

  Future<AppObject?> _registeredObject({
    required int workspaceId,
    required String dateKey,
    required int objectTypeId,
  }) async {
    final row = await genericStore.database.customSelect(
      '''SELECT object_id FROM daily_note_registry
         WHERE workspace_id = ? AND note_date = ? LIMIT 1''',
      variables: [
        Variable<int>(workspaceId),
        Variable<String>(dateKey),
      ],
    ).getSingleOrNull();
    if (row == null) return null;
    final objectId = row.read<int>('object_id');
    final objects = await objectStore.listObjects(objectTypeId);
    for (final object in objects) {
      if (object.id == objectId) return object;
    }
    return null;
  }

  String _dateKey(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
  }
}
