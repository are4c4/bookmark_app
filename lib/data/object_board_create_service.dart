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
  }) {
    return createWithObjectFactory(
      createObject: () =>
          _objectStore.createObject(objectTypeId: objectTypeId, title: title),
      groupProperty: groupProperty,
      targetGroup: targetGroup,
    );
  }

  /// Creates an Object through the caller's canonical authority, then applies
  /// the initial Board-group preset inside the same transaction.
  ///
  /// This lets identity-sensitive generic ObjectTypes (for example Person)
  /// preserve their canonical write boundary without duplicating Board preset
  /// semantics. The preset is validated before [createObject] runs, so an
  /// unsupported group cannot leave a partial created Object.
  Future<int> createWithObjectFactory({
    required Future<int> Function() createObject,
    required ObjectPropertyDefinition groupProperty,
    required ObjectGroupBucket<AppObject> targetGroup,
  }) async {
    // Validate/derive the preset before creating the Object so unsupported
    // grouped Properties cannot leave an orphan record.
    final value = planner.initialValue(
      property: groupProperty,
      targetGroup: targetGroup,
    );

    // The new Object and its initial Board-group preset are one logical write.
    // Nested canonical Object/Relation mutations participate in this transaction,
    // so a preset failure rolls back creation without best-effort cleanup.
    return relationMutations.genericStore.database.transaction(() async {
      final objectId = await createObject();
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
    });
  }
}
