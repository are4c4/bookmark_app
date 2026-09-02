import '../domain/object_group.dart';
import '../domain/object_model.dart';
import 'object_store.dart';

class ObjectBoardMovePlanner {
  const ObjectBoardMovePlanner();

  bool canMove(ObjectPropertyDefinition property) => switch (property.type) {
        ObjectPropertyType.title ||
        ObjectPropertyType.image ||
        ObjectPropertyType.file ||
        ObjectPropertyType.createdTime ||
        ObjectPropertyType.updatedTime ||
        ObjectPropertyType.formula ||
        ObjectPropertyType.rollup => false,
        _ => true,
      };

  dynamic nextValue({
    required AppObject object,
    required ObjectPropertyDefinition property,
    required ObjectGroupBucket<AppObject> sourceGroup,
    required ObjectGroupBucket<AppObject> targetGroup,
  }) {
    if (!canMove(property)) {
      throw StateError('${property.name} cannot be changed by Board drag/drop.');
    }

    final current = object.values[property.id];
    if (property.type == ObjectPropertyType.multiSelect) {
      return _moveListValue(
        current,
        sourceValue: sourceGroup.value,
        targetValue: targetGroup.value,
      );
    }

    if (property.type == ObjectPropertyType.objectRelation) {
      final currentIds = ObjectRelationValue.fromJson(current).objectIds;
      if (!property.allowsMultipleRelations) {
        final targetId = _asInt(targetGroup.value);
        return ObjectRelationValue(
          objectIds: targetId == null ? const <int>[] : <int>[targetId],
        );
      }
      final nextIds = _moveListValue(
        currentIds,
        sourceValue: _asInt(sourceGroup.value),
        targetValue: _asInt(targetGroup.value),
      ).whereType<int>().toList(growable: false);
      return ObjectRelationValue(objectIds: nextIds);
    }

    return targetGroup.value;
  }

  List<dynamic> _moveListValue(
    dynamic current, {
    required dynamic sourceValue,
    required dynamic targetValue,
  }) {
    final values = current is Iterable && current is! String
        ? current.toList(growable: true)
        : <dynamic>[];
    if (sourceValue != null) {
      values.removeWhere((value) => _sameValue(value, sourceValue));
    }
    if (targetValue != null &&
        !values.any((value) => _sameValue(value, targetValue))) {
      values.add(targetValue);
    }
    return values;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse('$value');
  }

  bool _sameValue(dynamic left, dynamic right) {
    if (left is num && right is num) return left == right;
    return '$left' == '$right';
  }
}

class ObjectBoardMoveService {
  ObjectBoardMoveService(
    this._objectStore, {
    this.planner = const ObjectBoardMovePlanner(),
  });

  final ObjectStore _objectStore;
  final ObjectBoardMovePlanner planner;

  Future<void> move({
    required AppObject object,
    required ObjectPropertyDefinition property,
    required ObjectGroupBucket<AppObject> sourceGroup,
    required ObjectGroupBucket<AppObject> targetGroup,
  }) async {
    if (sourceGroup.key == targetGroup.key) return;
    final value = planner.nextValue(
      object: object,
      property: property,
      sourceGroup: sourceGroup,
      targetGroup: targetGroup,
    );
    await _objectStore.setPropertyValue(
      objectId: object.id,
      property: property,
      value: value,
    );
  }
}
