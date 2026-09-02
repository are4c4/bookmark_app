import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

ObjectPropertyDefinition property(
  ObjectPropertyType type, {
  Map<String, dynamic> config = const {},
}) =>
    ObjectPropertyDefinition(
      id: 10,
      objectTypeId: 1,
      name: 'Group',
      type: type,
      sortOrder: 0,
      config: config,
    );

ObjectGroupBucket<AppObject> bucket(dynamic value) => ObjectGroupBucket<AppObject>(
      key: value == null ? '__empty__' : '$value',
      label: value == null ? '未設定' : '$value',
      value: value,
      items: const [],
    );

void main() {
  const planner = ObjectBoardCreatePlanner();

  test('uses scalar group value as initial Property value', () {
    expect(
      planner.initialValue(
        property: property(ObjectPropertyType.select),
        targetGroup: bucket('Done'),
      ),
      'Done',
    );
  });

  test('wraps multi-select group value in a list', () {
    expect(
      planner.initialValue(
        property: property(ObjectPropertyType.multiSelect),
        targetGroup: bucket('Math'),
      ),
      ['Math'],
    );
  });

  test('converts Relation bucket value to ObjectRelationValue', () {
    final result = planner.initialValue(
      property: property(
        ObjectPropertyType.objectRelation,
        config: const {'multiple': true, 'targetObjectTypeId': 2},
      ),
      targetGroup: bucket(42),
    ) as ObjectRelationValue;

    expect(result.objectIds, [42]);
  });

  test('unassigned bucket leaves the Property unset', () {
    expect(
      planner.initialValue(
        property: property(ObjectPropertyType.checkbox),
        targetGroup: bucket(null),
      ),
      isNull,
    );
  });

  test('computed Properties cannot be preset from Board', () {
    expect(planner.canPreset(property(ObjectPropertyType.formula)), false);
    expect(
      () => planner.initialValue(
        property: property(ObjectPropertyType.formula),
        targetGroup: bucket(10),
      ),
      throwsStateError,
    );
  });
}
