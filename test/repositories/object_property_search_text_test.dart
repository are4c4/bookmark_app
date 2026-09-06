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
      name: 'Value',
      type: type,
      sortOrder: 0,
      config: config,
    );

void main() {
  test('projects selected scalar Property types deterministically', () {
    expect(
      buildObjectPropertySearchText(
        property: property(ObjectPropertyType.text),
        value: '  searchable text  ',
      ),
      'searchable text',
    );
    expect(
      buildObjectPropertySearchText(
        property: property(ObjectPropertyType.url),
        value: 'https://example.com/reference',
      ),
      'https://example.com/reference',
    );
    expect(
      buildObjectPropertySearchText(
        property: property(ObjectPropertyType.number),
        value: 42.5,
      ),
      '42.5',
    );
    expect(
      buildObjectPropertySearchText(
        property: property(ObjectPropertyType.date),
        value: '2026-09-07',
      ),
      '2026-09-07',
    );
    expect(
      buildObjectPropertySearchText(
        property: property(ObjectPropertyType.rating),
        value: 4,
      ),
      '4',
    );
  });

  test('projects multi-select labels in persisted order and ignores blanks', () {
    expect(
      buildObjectPropertySearchText(
        property: property(ObjectPropertyType.multiSelect),
        value: const ['Flutter', '  Dart  ', '', 'SQLite'],
      ),
      'Flutter\nDart\nSQLite',
    );
  });

  test('does not expose relation or asset identity values as free text', () {
    for (final type in <ObjectPropertyType>[
      ObjectPropertyType.objectRelation,
      ObjectPropertyType.image,
      ObjectPropertyType.file,
    ]) {
      expect(
        buildObjectPropertySearchText(
          property: property(type),
          value: type == ObjectPropertyType.objectRelation
              ? const {'objectIds': [123456]}
              : '/private/storage/987654.bin',
        ),
        isEmpty,
      );
    }
  });

  test('leaves non-textual and computed Property families to other contributors',
      () {
    for (final type in <ObjectPropertyType>[
      ObjectPropertyType.title,
      ObjectPropertyType.checkbox,
      ObjectPropertyType.createdTime,
      ObjectPropertyType.updatedTime,
      ObjectPropertyType.formula,
      ObjectPropertyType.rollup,
    ]) {
      expect(
        buildObjectPropertySearchText(
          property: property(type),
          value: 'must-not-be-indexed-here',
        ),
        isEmpty,
      );
    }
  });

  test('explicit searchable false opts a Property out', () {
    expect(
      buildObjectPropertySearchText(
        property: property(
          ObjectPropertyType.text,
          config: const {'searchable': false},
        ),
        value: 'private-ish metadata',
      ),
      isEmpty,
    );
  });

  test('does not stringify structured values accidentally', () {
    expect(
      buildObjectPropertySearchText(
        property: property(ObjectPropertyType.text),
        value: const {'raw': 'do not stringify maps'},
      ),
      isEmpty,
    );
  });
}
