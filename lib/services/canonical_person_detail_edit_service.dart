import '../data/app_database.dart';
import '../data/generic_database_store.dart';
import '../data/object_body_store.dart';
import '../data/object_computed_value_store.dart';
import '../data/object_detail_content_loader.dart';
import '../data/object_detail_edit_service.dart';
import '../data/object_store.dart';
import '../data/person_object_bridge.dart';
import '../data/person_object_write_service.dart';
import '../data/system_object_store.dart';
import '../domain/object_detail_content.dart';
import '../domain/object_model.dart';

/// Routes generic Inspector edits for canonical Person Objects without bypassing
/// the temporary legacy People compatibility projection.
///
/// Legacy-backed Persons keep using [PersonObjectWriteService]. Native canonical
/// Person Objects without a legacy identity remain ordinary generic Objects.
class CanonicalPersonDetailEditService {
  CanonicalPersonDetailEditService({
    required this.database,
    required this.objectStore,
    required this.personBridge,
    required this.personWrites,
    required this.genericEdits,
    required this.loader,
  });

  factory CanonicalPersonDetailEditService.fromStores({
    required GenericDatabaseStore genericStore,
    required ObjectStore objectStore,
  }) {
    final database = genericStore.database;
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    final loader = ObjectDetailContentLoader(
      objectStore: objectStore,
      bodyStore: ObjectBodyStore(genericStore),
      computedStore: ObjectComputedValueStore(objectStore),
    );
    return CanonicalPersonDetailEditService(
      database: database,
      objectStore: objectStore,
      personBridge: bridge,
      personWrites: PersonObjectWriteService(
        database: database,
        objectStore: objectStore,
        personBridge: bridge,
      ),
      genericEdits: ObjectDetailEditService(
        objectStore: objectStore,
        bodyStore: ObjectBodyStore(genericStore),
        loader: loader,
      ),
      loader: loader,
    );
  }

  final AppDatabase database;
  final ObjectStore objectStore;
  final PersonObjectBridge personBridge;
  final PersonObjectWriteService personWrites;
  final ObjectDetailEditService genericEdits;
  final ObjectDetailContentLoader loader;

  Future<ObjectDetailContent> rename({
    required ObjectDetailContent content,
    required String title,
  }) async {
    final route = await _resolveRoute(content);
    if (route.legacyPersonId == null) {
      return genericEdits.rename(content: content, title: title);
    }

    await personWrites.update(
      workspaceId: content.objectType.workspaceId,
      personId: route.legacyPersonId!,
      name: title,
      note: _currentNote(content, route.schema.noteProperty),
    );
    return _reload(content);
  }

  Future<ObjectDetailContent> setNote({
    required ObjectDetailContent content,
    required ObjectPropertyDefinition property,
    required String? note,
  }) async {
    final route = await _resolveRoute(content);
    if (property.id != route.schema.noteProperty.id) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Only the canonical Person Note Property may be edited here.',
      );
    }

    if (route.legacyPersonId == null) {
      return genericEdits.setValue(
        content: content,
        property: property,
        value: note,
      );
    }

    await personWrites.update(
      workspaceId: content.objectType.workspaceId,
      personId: route.legacyPersonId!,
      name: content.object.title,
      note: note,
    );
    return _reload(content);
  }

  Future<_PersonEditRoute> _resolveRoute(ObjectDetailContent content) async {
    final workspaceId = content.objectType.workspaceId;
    final schema = await personBridge.ensurePersonObjectType(workspaceId);
    if (schema.objectType.id != content.objectType.id) {
      throw StateError('Object is not the canonical Person ObjectType.');
    }

    final mappedLegacyId = await personBridge.legacyPersonIdForObject(
      workspaceId,
      content.object.id,
    );
    final claimedLegacyId = _legacyId(
      content.object.values[schema.legacyPersonIdProperty.id],
    );

    if (mappedLegacyId == null) {
      if (claimedLegacyId != null) {
        throw StateError(
          'Canonical Person claims a legacy identity without a valid mapping.',
        );
      }
      return _PersonEditRoute(schema: schema, legacyPersonId: null);
    }

    if (claimedLegacyId != mappedLegacyId) {
      throw StateError(
        'Canonical Person mapping does not match its persisted legacy identity.',
      );
    }

    final matchingClaims = (await objectStore.listObjects(schema.objectType.id))
        .where(
          (object) =>
              _legacyId(object.values[schema.legacyPersonIdProperty.id]) ==
              mappedLegacyId,
        )
        .toList(growable: false);
    if (matchingClaims.length != 1 ||
        matchingClaims.single.id != content.object.id) {
      throw StateError(
        'Canonical Person legacy identity is ambiguous; refusing a partial edit.',
      );
    }

    return _PersonEditRoute(
      schema: schema,
      legacyPersonId: mappedLegacyId,
    );
  }

  String? _currentNote(
    ObjectDetailContent content,
    ObjectPropertyDefinition property,
  ) {
    final value = content.object.values[property.id];
    if (value == null) return null;
    if (value is! String) {
      throw StateError('Canonical Person Note is malformed.');
    }
    return value;
  }

  int? _legacyId(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse('$value');
  }

  Future<ObjectDetailContent> _reload(ObjectDetailContent content) async {
    final reloaded = await loader.load(
      objectTypeId: content.objectType.id,
      objectId: content.object.id,
    );
    if (reloaded == null) {
      throw StateError('Person disappeared while editing detail content.');
    }
    return reloaded;
  }
}

class _PersonEditRoute {
  const _PersonEditRoute({
    required this.schema,
    required this.legacyPersonId,
  });

  final PersonObjectSchema schema;
  final int? legacyPersonId;
}
