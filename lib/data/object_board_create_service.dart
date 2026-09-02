import '../domain/object_group.dart';
import '../domain/object_model.dart';
import 'object_board_move_service.dart';
import 'object_store.dart';

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
    this.planner = const ObjectBoardCreatePlanner(),
  });

  final ObjectStore _objectStore;
  final ObjectBoardCreatePlanner planner;

  Future<int> create({
    required int objectTypeId,
    required String title,
    required ObjectPropertyDefinition groupProperty,
    required ObjectGroupBucket<AppObject> targetGroup,
  }) async {
    final objectId = await _objectStore.createObject(
      objectTypeId: objectTypeId,
      title: title,
    );

    final value = planner.initialValue(
      property: groupProperty,
      targetGroup: targetGroup,
    );
    if (value != null) {
      await _objectStore.setPropertyValue(
        objectId: objectId,
        property: groupProperty,
        value: value,
      );
    }
    return objectId;
  }
}
