import '../domain/object_model.dart';

const Set<ObjectPropertyType> searchableObjectPropertyTypes = {
  ObjectPropertyType.text,
  ObjectPropertyType.number,
  ObjectPropertyType.date,
  ObjectPropertyType.url,
  ObjectPropertyType.select,
  ObjectPropertyType.multiSelect,
  ObjectPropertyType.rating,
};

/// Converts one typed Property value into deterministic user-facing text for
/// the canonical Object search projection.
///
/// Relations, asset/file identity values, checkboxes, timestamps and computed
/// values deliberately do not contribute here. They either need canonical
/// labels/derived metadata or add little useful free-text search signal.
///
/// System-maintained metadata also fails closed from this generic contributor
/// unless its schema explicitly opts into search with `searchable: true`.
/// Native/internal metadata should otherwise use a dedicated contributor rather
/// than becoming free-text merely because its storage type is text/number/date.
String buildObjectPropertySearchText({
  required ObjectPropertyDefinition property,
  required dynamic value,
}) {
  final searchable = property.config['searchable'];
  final systemManaged = property.config['system'] == true;
  if (searchable == false ||
      (systemManaged && searchable != true) ||
      !searchableObjectPropertyTypes.contains(property.type) ||
      value == null) {
    return '';
  }

  if (property.type == ObjectPropertyType.multiSelect) {
    final items = value is Iterable ? value : <dynamic>[value];
    return items
        .map(_scalarSearchText)
        .where((item) => item.isNotEmpty)
        .join('\n');
  }

  return _scalarSearchText(value);
}

/// Builds the selected typed-Property contribution for one canonical Object.
///
/// Property definitions are ordered by schema order then id so rebuild and
/// focused refresh produce the same token stream regardless of map iteration
/// order. Object title remains a dedicated search bucket and Relation/File/
/// Image/computed values continue through their own canonical contributors.
/// Dedicated domain contributors can claim Property ids through
/// [excludedPropertyIds] to prevent double indexing or accidental leakage of
/// metadata that the domain projection deliberately treats as non-searchable.
String buildObjectPropertiesSearchText({
  required AppObject object,
  required AppObjectType objectType,
  Set<int> excludedPropertyIds = const <int>{},
}) {
  if (object.objectTypeId != objectType.id) {
    throw ArgumentError(
      'Object ${object.id} belongs to ObjectType ${object.objectTypeId}, '
      'not ${objectType.id}.',
    );
  }

  final ordered = objectType.properties.toList(growable: false)
    ..sort((left, right) {
      final sortOrder = left.sortOrder.compareTo(right.sortOrder);
      if (sortOrder != 0) return sortOrder;
      return left.id.compareTo(right.id);
    });

  return ordered
      .where(
        (property) =>
            property.type != ObjectPropertyType.title &&
            !excludedPropertyIds.contains(property.id),
      )
      .map(
        (property) => buildObjectPropertySearchText(
          property: property,
          value: object.values[property.id],
        ),
      )
      .where((text) => text.isNotEmpty)
      .join('\n');
}

String _scalarSearchText(dynamic value) {
  if (value is String) return value.trim();
  if (value is num) return '$value';
  return '';
}
