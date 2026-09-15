import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/object_detail_empty_property_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scalarProperty = ObjectPropertyDefinition(
    id: 1,
    objectTypeId: 1,
    name: 'Optional note',
    type: ObjectPropertyType.text,
    sortOrder: 0,
  );
  const computedProperty = ObjectPropertyDefinition(
    id: 2,
    objectTypeId: 1,
    name: 'Formula result',
    type: ObjectPropertyType.formula,
    sortOrder: 1,
  );

  ObjectDetailPropertyPresentation presentation({
    ObjectPropertyDefinition property = scalarProperty,
    dynamic value,
    bool hidden = false,
  }) => ObjectDetailPropertyPresentation(
    property: property,
    value: value,
    displayText: value == null ? 'なし' : '$value',
    isHidden: hidden,
  );

  test('collapses only absent scalar presentation values', () {
    expect(
      ObjectDetailEmptyPropertyPolicy.isCollapsibleEmpty(presentation()),
      isTrue,
    );
    expect(
      ObjectDetailEmptyPropertyPolicy.isCollapsibleEmpty(
        presentation(value: '   '),
      ),
      isTrue,
    );
    expect(
      ObjectDetailEmptyPropertyPolicy.isCollapsibleEmpty(
        presentation(value: 'meaningful'),
      ),
      isFalse,
    );
  });

  test(
    'does not classify hidden or computed Properties as collapsible empty',
    () {
      expect(
        ObjectDetailEmptyPropertyPolicy.isCollapsibleEmpty(
          presentation(hidden: true),
        ),
        isFalse,
      );
      expect(
        ObjectDetailEmptyPropertyPolicy.isCollapsibleEmpty(
          presentation(property: computedProperty),
        ),
        isFalse,
      );
    },
  );
}
