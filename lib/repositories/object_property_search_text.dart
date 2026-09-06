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
String buildObjectPropertySearchText({
  required ObjectPropertyDefinition property,
  required dynamic value,
}) {
  if (property.config['searchable'] == false ||
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

String _scalarSearchText(dynamic value) {
  if (value is String) return value.trim();
  if (value is num) return '$value';
  return '';
}
