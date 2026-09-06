import '../data/weblink_object_service.dart';
import '../domain/object_model.dart';
import 'object_property_search_text.dart';

class WeblinkSearchProjection {
  const WeblinkSearchProjection({
    required this.text,
    required this.consumedPropertyIds,
  });

  final String text;

  /// Canonical Weblink system metadata owned by this projection.
  ///
  /// Callers should exclude these Property ids from the generic Property
  /// bucket. Searchable metadata is emitted through [text], while presentation
  /// media/content-type/date fields are consumed without becoming search text.
  final Set<int> consumedPropertyIds;
}

const List<String> _searchablePropertyNames = <String>[
  'URL',
  'Domain',
  'Page title',
  'Site name',
  'Description',
];

const Set<String> _ownedPropertyNames = <String>{
  ..._searchablePropertyNames,
  'Content type',
  'Published date',
  'Favicon URL',
  'Preview image URL',
};

/// Builds the dedicated Weblink metadata contribution for canonical Object
/// search.
///
/// Only user-meaningful resource metadata is emitted. Favicon/preview-image
/// URLs, content type and published date are owned by the Weblink projection so
/// they can be excluded from the generic Property bucket without becoming
/// searchable text themselves.
WeblinkSearchProjection buildWeblinkSearchProjection({
  required AppObject object,
  required AppObjectType objectType,
}) {
  if (object.objectTypeId != objectType.id) {
    throw ArgumentError(
      'Weblink search projection requires matching Object/ObjectType ids.',
    );
  }

  final propertiesByName = <String, ObjectPropertyDefinition>{};
  final orderedProperties = objectType.properties.toList(growable: false)
    ..sort((left, right) => left.id.compareTo(right.id));
  for (final property in orderedProperties) {
    propertiesByName.putIfAbsent(property.name, () => property);
  }

  final consumed = orderedProperties
      .where((property) => _ownedPropertyNames.contains(property.name))
      .map((property) => property.id)
      .toSet();
  final fragments = <String>[];
  for (final name in _searchablePropertyNames) {
    final property = propertiesByName[name];
    if (property == null) continue;
    final text = buildObjectPropertySearchText(
      property: property,
      value: object.values[property.id],
    );
    if (text.isNotEmpty) fragments.add(text);
  }

  return WeblinkSearchProjection(
    text: fragments.join('\n'),
    consumedPropertyIds: Set<int>.unmodifiable(consumed),
  );
}

/// Compatibility helper for callers that already hold the canonical Weblink
/// definition.
String buildWeblinkSearchText({
  required AppObject object,
  required WeblinkObjectDefinition definition,
}) =>
    buildWeblinkSearchProjection(
      object: object,
      objectType: definition.objectType,
    ).text;
