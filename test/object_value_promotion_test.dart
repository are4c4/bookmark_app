import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_value_promotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ObjectPropertyDefinition property(ObjectPropertyType type) =>
      ObjectPropertyDefinition(
        id: 1,
        objectTypeId: 10,
        name: 'Source',
        type: type,
        sortOrder: 0,
      );

  const planner = ObjectValuePromotionPlanner();

  test('plans a reversible Value-to-Object promotion by default', () {
    final plan = planner.plan(
      sourceProperty: property(ObjectPropertyType.text),
      sourceValue: '夏目漱石',
      targetObjectTypeId: 20,
      targetObjectTitle: ' 夏目漱石 ',
      relationPropertyName: ' Author ',
    );

    expect(plan.sourceProperty.type, ObjectPropertyType.text);
    expect(plan.sourceValue, '夏目漱石');
    expect(plan.targetObjectTypeId, 20);
    expect(plan.targetObjectTitle, '夏目漱石');
    expect(plan.relationPropertyName, 'Author');
    expect(plan.preservesSourceValue, isTrue);
    expect(plan.requiresDestructiveConfirmation, isFalse);
  });

  test('explicit scalar clearing is marked as potentially destructive', () {
    final plan = planner.plan(
      sourceProperty: property(ObjectPropertyType.url),
      sourceValue: 'https://example.com',
      targetObjectTypeId: 30,
      targetObjectTitle: 'Example',
      relationPropertyName: 'Weblink',
      sourceDisposition: ObjectValuePromotionSourceDisposition.clearAfterLink,
    );

    expect(plan.preservesSourceValue, isFalse);
    expect(plan.requiresDestructiveConfirmation, isTrue);
  });

  test('rejects Relation and Computed properties as promotion sources', () {
    for (final type in <ObjectPropertyType>[
      ObjectPropertyType.objectRelation,
      ObjectPropertyType.formula,
      ObjectPropertyType.rollup,
    ]) {
      expect(
        () => planner.plan(
          sourceProperty: property(type),
          sourceValue: 'value',
          targetObjectTypeId: 20,
          targetObjectTitle: 'Target',
          relationPropertyName: 'Relation',
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects incomplete promotion targets without side effects', () {
    expect(
      () => planner.plan(
        sourceProperty: property(ObjectPropertyType.text),
        sourceValue: null,
        targetObjectTypeId: 20,
        targetObjectTitle: 'Target',
        relationPropertyName: 'Relation',
      ),
      throwsArgumentError,
    );
    expect(
      () => planner.plan(
        sourceProperty: property(ObjectPropertyType.text),
        sourceValue: 'value',
        targetObjectTypeId: 0,
        targetObjectTitle: 'Target',
        relationPropertyName: 'Relation',
      ),
      throwsArgumentError,
    );
    expect(
      () => planner.plan(
        sourceProperty: property(ObjectPropertyType.text),
        sourceValue: 'value',
        targetObjectTypeId: 20,
        targetObjectTitle: '   ',
        relationPropertyName: 'Relation',
      ),
      throwsArgumentError,
    );
  });
}
