import 'package:bookmark_app/data/object_board_move_service.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

const planner = ObjectBoardMovePlanner();

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

AppObject object(dynamic value) => AppObject(
      id: 1,
      objectTypeId: 1,
      title: 'A',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      values: {10: value},
    );

ObjectGroupBucket<AppObject> group(String key, dynamic value) =>
    ObjectGroupBucket<AppObject>(
      key: key,
      label: value == null ? '未設定' : '$value',
      value: value,
      items: const [],
      isEmptyGroup: value == null,
    );

void main() {
  test('single-value properties take the target bucket value', () {
    final next = planner.nextValue(
      object: object('todo'),
      property: property(ObjectPropertyType.select),
      sourceGroup: group('todo', 'todo'),
      targetGroup: group('done', 'done'),
    );
    expect(next, 'done');
  });

  test('moving to the unassigned bucket clears a scalar property', () {
    final next = planner.nextValue(
      object: object(true),
      property: property(ObjectPropertyType.checkbox),
      sourceGroup: group('true', true),
      targetGroup: group('empty', null),
    );
    expect(next, isNull);
  });

  test('multi-select replaces only the dragged source value', () {
    final next = planner.nextValue(
      object: object(['数学', '本']),
      property: property(ObjectPropertyType.multiSelect),
      sourceGroup: group('math', '数学'),
      targetGroup: group('work', '仕事'),
    ) as List<dynamic>;
    expect(next, ['本', '仕事']);
  });

  test('multi-select move to unassigned removes only the source value', () {
    final next = planner.nextValue(
      object: object(['数学', '本']),
      property: property(ObjectPropertyType.multiSelect),
      sourceGroup: group('math', '数学'),
      targetGroup: group('empty', null),
    ) as List<dynamic>;
    expect(next, ['本']);
  });

  test('multiple Relation preserves unrelated target ids', () {
    final next = planner.nextValue(
      object: object({'objectIds': [20, 30]}),
      property: property(
        ObjectPropertyType.objectRelation,
        config: const {'targetObjectTypeId': 2, 'multiple': true},
      ),
      sourceGroup: group('20', 20),
      targetGroup: group('40', 40),
    ) as ObjectRelationValue;
    expect(next.objectIds, [30, 40]);
  });

  test('single Relation is replaced by the target id', () {
    final next = planner.nextValue(
      object: object(20),
      property: property(
        ObjectPropertyType.objectRelation,
        config: const {'targetObjectTypeId': 2, 'multiple': false},
      ),
      sourceGroup: group('20', 20),
      targetGroup: group('30', 30),
    ) as ObjectRelationValue;
    expect(next.objectIds, [30]);
  });

  test('computed and system-managed properties cannot be moved', () {
    expect(planner.canMove(property(ObjectPropertyType.formula)), isFalse);
    expect(planner.canMove(property(ObjectPropertyType.rollup)), isFalse);
    expect(planner.canMove(property(ObjectPropertyType.createdTime)), isFalse);
    expect(
      () => planner.nextValue(
        object: object(1),
        property: property(ObjectPropertyType.formula),
        sourceGroup: group('1', 1),
        targetGroup: group('2', 2),
      ),
      throwsStateError,
    );
  });
}
