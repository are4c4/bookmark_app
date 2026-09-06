import 'dart:developer' as developer;

import '../domain/object_group.dart';
import '../domain/object_model.dart';
import 'object_board_move_service.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';

class ObjectBoardCreatePlanner {
  const ObjectBoardCreatePlanner({
    this.movePlanner = const ObjectBoardMovePlanner(),
  });

  final ObjectBoardMovePlanner movePlanner;

  bool canPreset(ObjectPropertyDefinition property) =>
      movePlanner.canMove(property);

  dynamic initialValue({
    required ObjectPropertyDefinition property,
    required ObjectGroupBucket<AppObject> targetGroup,
  }) {
    if (!canPreset(property)) {
      throw StateError(
        '${property.name} cannot be preset when creating from Board.',
      );
    }

    final value = targetGroup.value;
    if (value == null) return null;

    if (property.type == ObjectPropertyType.multiSelect) {
      return <dynamic>[value];
    }

    if (property.type == ObjectPropertyType.objectRelation) {
      final targetId = _asInt(value);
      return ObjectRelationValue(
        objectIds: targetId == null ? const <int>[] : <int>[targetId],
      );
    }

    return value;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse('$value');
  }
}

class ObjectBoardCreateService {
  ObjectBoardCreateService(
    this._objectStore, {
    required this.relationMutations,
    this.planner = const ObjectBoardCreatePlanner(),
  });

  final ObjectStore _objectStore;
  final RelationMutationService relationMutations;
  final ObjectBoardCreatePlanner planner;

  Future<int> create({
    required int objectTypeId,
    required String title,
    required ObjectPropertyDefinition groupProperty,
    required ObjectGroupBucket<AppObject> targetGroup,
  }) async {
    // Validate/derive the preset before creating the Object so unsupported
    // grouped Properties cannot leave an orphan record.
    final value = planner.initialValue(
      property: groupProperty,
      targetGroup: targetGroup,
    );

    final objectId = await _objectStore.createObject(
      objectTypeId: objectTypeId,
      title: title,
    );
    try {
      if (value != null) {
        if (groupProperty.isRelation) {
          final relation = value is ObjectRelationValue
              ? value
              : ObjectRelationValue.fromJson(value);
          await relationMutations.setRelation(
            objectId: objectId,
            property: groupProperty,
            targetObjectIds: relation.objectIds,
          );
        } else {
          await _objectStore.setPropertyValue(
            objectId: objectId,
            property: groupProperty,
            value: value,
          );
        }
      }
      return objectId;
    } catch (_) {
      // This Object was created by this operation and has not been exposed to
      // the caller yet. Roll it back if the grouped preset cannot be written.
      // Cleanup is best-effort: a secondary delete failure must not replace the
      // original preset-write failure reported to the caller.
      try {
        await _objectStore.deleteObject(objectId);
      } catch (_, stackTrace) {
        _debugRollbackCleanupFailure(stackTrace);
      }
      rethrow;
    }
  }

  void _debugRollbackCleanupFailure(StackTrace stackTrace) {
    assert(() {
      developer.log(
        'Board Object rollback cleanup failed.',
        name: 'bookmark_app.object_board_create',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }
}
