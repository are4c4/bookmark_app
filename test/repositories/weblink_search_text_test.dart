import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/weblink_search_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ObjectPropertyDefinition property({
    required int id,
    required String name,
    required ObjectPropertyType type,
    Map<String, dynamic> config = const <String, dynamic>{},
  }) => ObjectPropertyDefinition(
        id: id,
        objectTypeId: 10,
        name: name,
        type: type,
        sortOrder: id,
        config: config,
      );

  WeblinkObjectDefinition definition({bool searchableDescription = true}) {
    final url = property(id: 1, name: 'URL', type: ObjectPropertyType.url);
    final domain = property(id: 2, name: 'Domain', type: ObjectPropertyType.text);
    final pageTitle =
        property(id: 3, name: 'Page title', type: ObjectPropertyType.text);
    final siteName =
        property(id: 4, name: 'Site name', type: ObjectPropertyType.text);
    final description = property(
      id: 5,
      name: 'Description',
      type: ObjectPropertyType.text,
      config: searchableDescription
          ? const <String, dynamic>{}
          : const <String, dynamic>{'searchable': false},
    );
    final contentType =
        property(id: 6, name: 'Content type', type: ObjectPropertyType.text);
    final publishedDate = property(
      id: 7,
      name: 'Published date',
      type: ObjectPropertyType.date,
    );
    final favicon =
        property(id: 8, name: 'Favicon URL', type: ObjectPropertyType.url);
    final preview = property(
      id: 9,
      name: 'Preview image URL',
      type: ObjectPropertyType.url,
    );
    return WeblinkObjectDefinition(
      objectType: AppObjectType(
        id: 10,
        workspaceId: 1,
        name: 'Weblink',
        icon: '🔗',
        kind: ObjectTypeKind.system,
        sortOrder: 0,
        properties: <ObjectPropertyDefinition>[
          url,
          domain,
          pageTitle,
          siteName,
          description,
          contentType,
          publishedDate,
          favicon,
          preview,
        ],
      ),
      urlProperty: url,
      domainProperty: domain,
      pageTitleProperty: pageTitle,
      siteNameProperty: siteName,
      descriptionProperty: description,
      contentTypeProperty: contentType,
      publishedDateProperty: publishedDate,
      faviconUrlProperty: favicon,
      previewImageUrlProperty: preview,
    );
  }

  AppObject weblink(Map<int, dynamic> values) => AppObject(
        id: 100,
        objectTypeId: 10,
        title: 'Canonical Object title',
        createdAt: DateTime.utc(2026, 9, 7),
        updatedAt: DateTime.utc(2026, 9, 7),
        values: values,
      );

  test('emits resource metadata but excludes presentation-media URLs', () {
    final text = buildWeblinkSearchText(
      object: weblink(<int, dynamic>{
        1: 'https://example.com/articles/search',
        2: 'example.com',
        3: 'Canonical Search Architecture',
        4: 'Example Research',
        5: 'A description users should be able to discover.',
        6: 'text/html',
        7: '2026-09-07',
        8: 'https://cdn.example.com/favicon-secret-token.png',
        9: 'https://cdn.example.com/preview-secret-token.jpg',
      }),
      definition: definition(),
    );

    expect(
      text,
      'https://example.com/articles/search\n'
      'example.com\n'
      'Canonical Search Architecture\n'
      'Example Research\n'
      'A description users should be able to discover.',
    );
    expect(text, isNot(contains('favicon-secret-token')));
    expect(text, isNot(contains('preview-secret-token')));
    expect(text, isNot(contains('text/html')));
    expect(text, isNot(contains('2026-09-07')));
  });

  test('owns hidden Weblink metadata so generic Properties can exclude it', () {
    final base = definition();
    final notes = property(id: 10, name: 'Notes', type: ObjectPropertyType.text);
    final type = base.objectType.copyWith(
      properties: <ObjectPropertyDefinition>[
        ...base.objectType.properties,
        notes,
      ],
    );
    final projection = buildWeblinkSearchProjection(
      object: weblink(<int, dynamic>{
        1: 'https://example.com/articles/search',
        2: 'example.com',
        3: 'Canonical Search Architecture',
        4: 'Example Research',
        5: 'Description Token',
        6: 'application/private-token',
        7: '2099-12-31',
        8: 'https://cdn.example.com/favicon-private-token.png',
        9: 'https://cdn.example.com/preview-private-token.jpg',
        10: 'User Notes Token',
      }),
      objectType: type,
    );

    expect(projection.consumedPropertyIds, <int>{1, 2, 3, 4, 5, 6, 7, 8, 9});
    expect(projection.consumedPropertyIds, isNot(contains(notes.id)));
    expect(projection.text, contains('Canonical Search Architecture'));
    expect(projection.text, isNot(contains('private-token')));
    expect(projection.text, isNot(contains('2099-12-31')));
    expect(projection.text, isNot(contains('User Notes Token')));
  });

  test('inherits explicit searchable false from metadata Property', () {
    final text = buildWeblinkSearchText(
      object: weblink(<int, dynamic>{
        1: 'https://example.com',
        5: 'PrivateDescriptionToken',
      }),
      definition: definition(searchableDescription: false),
    );

    expect(text, 'https://example.com');
    expect(text, isNot(contains('PrivateDescriptionToken')));
  });

  test('rejects mismatched Object identity', () {
    final base = definition();
    final mismatched = AppObject(
      id: 100,
      objectTypeId: 999,
      title: 'Wrong type',
      createdAt: DateTime.utc(2026, 9, 7),
      updatedAt: DateTime.utc(2026, 9, 7),
    );

    expect(
      () => buildWeblinkSearchProjection(
        object: mismatched,
        objectType: base.objectType,
      ),
      throwsArgumentError,
    );
  });
}
