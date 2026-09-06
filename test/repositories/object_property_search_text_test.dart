import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_property_search_text.dart';
import 'package:flutter_test/flutter_test.dart';

ObjectPropertyDefinition property(
  ObjectPropertyType type, {
  int id = 1,
  int objectTypeId = 1,
  int sortOrder = 0,
  String name = 'Value',
  Map<String, dynamic> config = const <String, dynamic>{},
}) =>
    ObjectPropertyDefinition(
      id: id,
      objectTypeId: objectTypeId,
      name: name,
      type: type,
      sortOrder: sortOrder,
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

  test('whole-Object projection follows schema order and contributor boundaries',
      () {
    final title = property(
      ObjectPropertyType.title,
      id: 10,
      sortOrder: 0,
      name: 'Title',
    );
    final multi = property(
      ObjectPropertyType.multiSelect,
      id: 20,
      sortOrder: 1,
      name: 'Topics',
    );
    final text = property(
      ObjectPropertyType.text,
      id: 30,
      sortOrder: 2,
      name: 'Summary',
    );
    final relation = property(
      ObjectPropertyType.objectRelation,
      id: 40,
      sortOrder: 3,
      name: 'Person',
      config: const <String, dynamic>{
        'targetObjectTypeId': 2,
        'multiple': true,
      },
    );
    final file = property(
      ObjectPropertyType.file,
      id: 50,
      sortOrder: 4,
      name: 'Attachment',
    );
    final hidden = property(
      ObjectPropertyType.text,
      id: 60,
      sortOrder: 5,
      name: 'Hidden from search',
      config: const <String, dynamic>{'searchable': false},
    );
    final objectType = AppObjectType(
      id: 1,
      workspaceId: 1,
      name: 'Knowledge item',
      icon: '🧠',
      kind: ObjectTypeKind.custom,
      sortOrder: 0,
      properties: <ObjectPropertyDefinition>[
        hidden,
        text,
        relation,
        multi,
        file,
        title,
      ],
    );
    final object = AppObject(
      id: 100,
      objectTypeId: 1,
      title: 'Canonical title bucket',
      createdAt: DateTime.utc(2026, 9, 7),
      updatedAt: DateTime.utc(2026, 9, 7),
      values: <int, dynamic>{
        title.id: 'Do not duplicate title here',
        multi.id: const <String>['First topic', 'Second topic'],
        text.id: 'Later summary',
        relation.id: const <String, dynamic>{'objectIds': <int>[999999]},
        file.id: '/private/asset/secret.bin',
        hidden.id: 'PrivateSearchToken',
      },
    );

    final projected = buildObjectPropertiesSearchText(
      object: object,
      objectType: objectType,
    );

    expect(projected, 'First topic\nSecond topic\nLater summary');
    expect(projected, isNot(contains('Do not duplicate title here')));
    expect(projected, isNot(contains('999999')));
    expect(projected, isNot(contains('/private/asset')));
    expect(projected, isNot(contains('PrivateSearchToken')));
  });

  test('dedicated contributors can exclude owned Property ids', () {
    final dedicated = property(
      ObjectPropertyType.text,
      id: 10,
      sortOrder: 0,
      name: 'Dedicated metadata',
    );
    final generic = property(
      ObjectPropertyType.text,
      id: 20,
      sortOrder: 1,
      name: 'User notes',
    );
    final objectType = AppObjectType(
      id: 1,
      workspaceId: 1,
      name: 'Specialized type',
      icon: '📦',
      kind: ObjectTypeKind.system,
      sortOrder: 0,
      properties: <ObjectPropertyDefinition>[dedicated, generic],
    );
    final object = AppObject(
      id: 100,
      objectTypeId: 1,
      title: 'Object',
      createdAt: DateTime.utc(2026, 9, 7),
      updatedAt: DateTime.utc(2026, 9, 7),
      values: <int, dynamic>{
        dedicated.id: 'DedicatedToken',
        generic.id: 'GenericToken',
      },
    );

    expect(
      buildObjectPropertiesSearchText(
        object: object,
        objectType: objectType,
        excludedPropertyIds: <int>{dedicated.id},
      ),
      'GenericToken',
    );
  });

  test('whole-Object projection rejects a mismatched ObjectType', () {
    final object = AppObject(
      id: 100,
      objectTypeId: 1,
      title: 'Object',
      createdAt: DateTime.utc(2026, 9, 7),
      updatedAt: DateTime.utc(2026, 9, 7),
    );
    const otherType = AppObjectType(
      id: 2,
      workspaceId: 1,
      name: 'Other',
      icon: '📦',
      kind: ObjectTypeKind.custom,
      sortOrder: 0,
    );

    expect(
      () => buildObjectPropertiesSearchText(
        object: object,
        objectType: otherType,
      ),
      throwsArgumentError,
    );
  });
}
