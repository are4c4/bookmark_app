import 'package:bookmark_app/domain/object_detail_content.dart';
import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const presenter = ObjectDetailPropertyPresenter();
  final now = DateTime(2026, 9, 3);

  ObjectPropertyDefinition property(
    int id,
    ObjectPropertyType type, {
    Map<String, dynamic> config = const <String, dynamic>{},
  }) =>
      ObjectPropertyDefinition(
        id: id,
        objectTypeId: 10,
        name: 'P$id',
        type: type,
        sortOrder: id,
        config: config,
      );

  ObjectDetailContent content({
    Map<int, dynamic> values = const <int, dynamic>{},
    Map<int, dynamic> computed = const <int, dynamic>{},
  }) {
    return ObjectDetailContent(
      object: AppObject(
        id: 1,
        objectTypeId: 10,
        title: 'Object',
        createdAt: now,
        updatedAt: now,
        values: values,
      ),
      objectType: const AppObjectType(
        id: 10,
        workspaceId: 1,
        name: 'Type',
        icon: 'T',
        kind: ObjectTypeKind.custom,
        sortOrder: 0,
      ),
      computedValues: computed,
    );
  }

  test('formats ordinary values consistently', () {
    expect(presenter.formatValue(null), 'なし');
    expect(presenter.formatValue(true), 'はい');
    expect(presenter.formatValue(false), 'いいえ');
    expect(presenter.formatValue(['A', 'B']), 'A, B');
    expect(presenter.formatValue(12.5), '12.5');
  });

  test('reads computed values from ObjectDetailContent', () {
    final formula = property(7, ObjectPropertyType.formula);
    final result = presenter.present(
      content: content(computed: {7: 42}),
      property: formula,
    );

    expect(result.value, 42);
    expect(result.displayText, '42');
    expect(result.isComputed, isTrue);
  });

  test('Relations require canonical relation renderer instead of raw ids', () {
    final relation = property(
      8,
      ObjectPropertyType.objectRelation,
      config: const {'targetObjectTypeId': 20, 'multiple': true},
    );
    final result = presenter.present(
      content: content(values: {
        8: const ObjectRelationValue(objectIds: [3, 4]),
      }),
      property: relation,
    );

    expect(result.usesRelationRenderer, isTrue);
    expect(result.displayText, isNull);
  });

  test('hidden Property state is surfaced without removing the row implicitly', () {
    final hidden = property(
      9,
      ObjectPropertyType.text,
      config: const {'hidden': true},
    );
    final result = presenter.present(
      content: content(values: {9: 'secret'}),
      property: hidden,
    );

    expect(result.isHidden, isTrue);
    expect(result.displayText, 'secret');
  });
}
