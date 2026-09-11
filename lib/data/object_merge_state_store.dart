import 'dart:convert';

import '../domain/object_merge_state_planner.dart';
import '../domain/object_model.dart';
import 'generic_database_store.dart';
import 'object_alias_store.dart';
import 'object_body_store.dart';
import 'object_store.dart';

/// Persistence boundary for the A-owned half of explicit Object merge state.
///
/// Relation Properties are deliberately excluded. A merge coordinator must
/// compose this store with the B-owned canonical Relation merge service rather
/// than writing Relation payloads through this boundary.
class ObjectMergeStateStore {
  ObjectMergeStateStore(this.genericStore)
    : objectStore = ObjectStore(genericStore),
      bodyStore = ObjectBodyStore(genericStore),
      aliasStore = ObjectAliasStore(genericStore);

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final ObjectBodyStore bodyStore;
  final ObjectAliasStore aliasStore;

  Future<ObjectMergeStateSnapshot> capture({
    required int objectTypeId,
    required int objectId,
  }) async {
    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'Merge ObjectType does not exist.',
      );
    }

    AppObject? object;
    for (final candidate in await objectStore.listObjects(objectTypeId)) {
      if (candidate.id == objectId) {
        object = candidate;
        break;
      }
    }
    if (object == null) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Merge Object does not belong to the supplied ObjectType.',
      );
    }

    final valueProperties =
        objectType.properties
            .where((property) => property.isValue)
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));

    return ObjectMergeStateSnapshot(
      objectId: object.id,
      objectTypeId: objectType.id,
      title: object.title,
      propertySnapshots: <ObjectMergeValuePropertySnapshot>[
        for (final property in valueProperties)
          ObjectMergeValuePropertySnapshot.fromDefinition(
            property: property,
            value: object.values[property.id],
          ),
      ],
      body: await bodyStore.read(objectId),
      aliases: await aliasStore.listAliases(objectId),
    );
  }

  /// Persists [next] only when the complete current A-owned state still equals
  /// [expected].
  ///
  /// The compare and all writes run inside one outer transaction. Callers can
  /// therefore compose this with B-owned Relation rewiring, redirect creation,
  /// and retired-Object deletion while retaining rollback across the whole
  /// explicit merge.
  Future<bool> writeIfUnchanged({
    required ObjectMergeStateSnapshot expected,
    required ObjectMergeStateSnapshot next,
  }) async {
    _validateIdentity(expected: expected, next: next);

    return genericStore.database.transaction(() async {
      final current = await capture(
        objectTypeId: expected.objectTypeId,
        objectId: expected.objectId,
      );
      if (!_sameSnapshot(current, expected)) return false;

      final objectType = await objectStore.getObjectType(expected.objectTypeId);
      if (objectType == null) {
        throw StateError('Merge ObjectType disappeared during persistence.');
      }
      final valueProperties = <int, ObjectPropertyDefinition>{
        for (final property in objectType.properties.where(
          (property) => property.isValue,
        ))
          property.id: property,
      };
      final nextPropertyIds = next.propertySnapshots
          .map((snapshot) => snapshot.propertyId)
          .toSet();
      if (valueProperties.keys.toSet().length != nextPropertyIds.length ||
          !valueProperties.keys.toSet().containsAll(nextPropertyIds)) {
        throw StateError(
          'Object merge Property schema changed before A-owned state persistence.',
        );
      }

      await objectStore.renameObject(next.objectId, next.title);
      for (final snapshot in next.propertySnapshots) {
        final property = valueProperties[snapshot.propertyId];
        if (property == null || property.type != snapshot.type) {
          throw StateError(
            'Object merge Property identity/type changed before persistence.',
          );
        }
        await objectStore.setPropertyValue(
          objectId: next.objectId,
          property: property,
          value: snapshot.value,
        );
      }
      await bodyStore.write(objectId: next.objectId, document: next.body);
      await aliasStore.replaceAliases(
        objectId: next.objectId,
        aliases: next.aliases,
      );

      final persisted = await capture(
        objectTypeId: next.objectTypeId,
        objectId: next.objectId,
      );
      if (!_sameSnapshot(persisted, next)) {
        throw StateError(
          'Object merge A-owned state did not persist exactly as resolved.',
        );
      }
      return true;
    });
  }

  void _validateIdentity({
    required ObjectMergeStateSnapshot expected,
    required ObjectMergeStateSnapshot next,
  }) {
    if (expected.objectId != next.objectId ||
        expected.objectTypeId != next.objectTypeId) {
      throw ArgumentError(
        'Object merge persistence cannot change canonical Object identity or ObjectType.',
      );
    }
  }

  bool _sameSnapshot(
    ObjectMergeStateSnapshot left,
    ObjectMergeStateSnapshot right,
  ) => jsonEncode(_snapshotJson(left)) == jsonEncode(_snapshotJson(right));

  Map<String, dynamic> _snapshotJson(ObjectMergeStateSnapshot snapshot) =>
      <String, dynamic>{
        'objectId': snapshot.objectId,
        'objectTypeId': snapshot.objectTypeId,
        'title': snapshot.title,
        'properties': <Map<String, dynamic>>[
          for (final property in snapshot.propertySnapshots)
            <String, dynamic>{
              'id': property.propertyId,
              'type': property.type.name,
              'value': property.value,
            },
        ],
        'body': snapshot.body.toJson(),
        'aliases': snapshot.aliases,
      };
}
