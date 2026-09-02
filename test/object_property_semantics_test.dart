import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ObjectPropertyDefinition property(ObjectPropertyType type) =>
      ObjectPropertyDefinition(
        id: 1,
        objectTypeId: 1,
        name: type.name,
        type: type,
        sortOrder: 0,
      );

  test('lightweight property formats are value semantics', () {
    const valueTypes = <ObjectPropertyType>[
      ObjectPropertyType.title,
      ObjectPropertyType.text,
      ObjectPropertyType.number,
      ObjectPropertyType.checkbox,
      ObjectPropertyType.date,
      ObjectPropertyType.url,
      ObjectPropertyType.select,
      ObjectPropertyType.multiSelect,
      ObjectPropertyType.image,
      ObjectPropertyType.file,
      ObjectPropertyType.rating,
      ObjectPropertyType.createdTime,
      ObjectPropertyType.updatedTime,
    ];

    for (final type in valueTypes) {
      final definition = property(type);
      expect(definition.semantics, ObjectPropertySemantics.value);
      expect(definition.isValue, isTrue);
      expect(definition.isRelation, isFalse);
      expect(definition.isComputed, isFalse);
    }
  });

  test('Object Relation is distinct from value properties', () {
    final definition = property(ObjectPropertyType.objectRelation);

    expect(definition.semantics, ObjectPropertySemantics.objectRelation);
    expect(definition.isValue, isFalse);
    expect(definition.isRelation, isTrue);
    expect(definition.isComputed, isFalse);
  });

  test('Formula and Rollup are computed semantics', () {
    for (final type in <ObjectPropertyType>[
      ObjectPropertyType.formula,
      ObjectPropertyType.rollup,
    ]) {
      final definition = property(type);
      expect(definition.semantics, ObjectPropertySemantics.computed);
      expect(definition.isValue, isFalse);
      expect(definition.isRelation, isFalse);
      expect(definition.isComputed, isTrue);
    }
  });
}
