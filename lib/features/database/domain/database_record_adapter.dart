import '../../../database/database_definition.dart';

/// Runtime value paired with its database property definition.
///
/// Presentation widgets consume this object instead of knowing whether the
/// value came from bookmarks, people, photos, or a generic database table.
class DatabasePropertyValue {
  const DatabasePropertyValue({
    required this.definition,
    this.value,
  });

  final DatabasePropertyDefinition definition;
  final Object? value;

  bool get isEmpty {
    final current = value;
    if (current == null) return true;
    if (current is String) return current.trim().isEmpty;
    if (current is Iterable) return current.isEmpty;
    return false;
  }
}

/// Minimal adapter contract required by shared database presentation widgets.
///
/// Feature-specific repositories keep their existing storage model. An
/// adapter only translates a record into common display semantics.
abstract class DatabaseRecordAdapter<T> {
  const DatabaseRecordAdapter();

  Object idOf(T record);

  String titleOf(T record);

  String? subtitleOf(T record) => null;

  /// Local file path or remote URL used as the primary visual for a card.
  String? imageSourceOf(T record) => null;

  DatabasePropertyValue propertyValue(
    T record,
    DatabasePropertyDefinition property,
  );

  List<DatabasePropertyValue> propertyValues(
    T record,
    DatabaseDefinition definition,
  ) => definition.properties
      .map((property) => propertyValue(record, property))
      .toList(growable: false);
}
