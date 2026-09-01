import '../../database/domain/database_record_adapter.dart';
import '../../../database/database_definition.dart';

/// Shared textual representation used when a full interactive property widget
/// is not appropriate (for example compact list subtitles or table cells).
String formatDatabasePropertyValue(
  DatabasePropertyType type,
  Object? value,
) {
  if (value == null) return '';

  switch (type) {
    case DatabasePropertyType.checkbox:
      return value == true ? '✓' : '';
    case DatabasePropertyType.multiSelect:
      if (value is Iterable) {
        return value.map((item) => '$item').where((item) => item.isNotEmpty).join(', ');
      }
      return '$value';
    case DatabasePropertyType.rating:
      final numeric = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      return '★' * numeric.clamp(0, 5);
    case DatabasePropertyType.date:
      if (value is DateTime) {
        final local = value.toLocal();
        String two(int number) => number.toString().padLeft(2, '0');
        return '${local.year}/${two(local.month)}/${two(local.day)}';
      }
      return '$value';
    default:
      return '$value';
  }
}

String formatDatabaseProperty(
  DatabasePropertyValue property,
) => formatDatabasePropertyValue(property.definition.type, property.value);
