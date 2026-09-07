import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_property_search_text.dart';
import 'package:flutter_test/flutter_test.dart';

ObjectPropertyDefinition property(
  ObjectPropertyType type, {
  Map<String, dynamic> config = const <String, dynamic>{},
}) =>
    ObjectPropertyDefinition(
      id: 1,
      objectTypeId: 1,
      name: 'Metadata',
      type: type,
      sortOrder: 0,
      config: config,
    );

void main() {
  test('system-maintained typed metadata fails closed by default', () {
    for (final entry in <(ObjectPropertyType, dynamic)>[
      (ObjectPropertyType.text, 'internal-token'),
      (ObjectPropertyType.number, 424242),
      (ObjectPropertyType.date, '2026-09-07'),
    ]) {
      expect(
        buildObjectPropertySearchText(
          property: property(
            entry.$1,
            config: const <String, dynamic>{'system': true},
          ),
          value: entry.$2,
        ),
        isEmpty,
      );
    }
  });

  test('system-maintained metadata can explicitly opt into generic search', () {
    expect(
      buildObjectPropertySearchText(
        property: property(
          ObjectPropertyType.text,
          config: const <String, dynamic>{
            'system': true,
            'searchable': true,
          },
        ),
        value: 'ApprovedSystemToken',
      ),
      'ApprovedSystemToken',
    );
  });

  test('ordinary user-facing typed Properties keep existing search behavior', () {
    expect(
      buildObjectPropertySearchText(
        property: property(ObjectPropertyType.text),
        value: 'UserFacingToken',
      ),
      'UserFacingToken',
    );
  });
}
