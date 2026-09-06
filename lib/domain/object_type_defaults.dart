import 'object_body.dart';

enum ObjectOpenMode {
  sidePeek,
  centerPeek,
  fullPage,
}

/// Reusable defaults owned by an ObjectType.
///
/// Database and View layers may override presentation values, but those
/// overrides are intentionally not stored here. This keeps ObjectType defaults
/// reusable while preserving the resolution order
/// `View > Database > ObjectType > app`.
///
/// [bodyTemplate] is different: it is an Object creation default. New Objects
/// receive a copy of the document while existing Objects keep their own Body.
class ObjectTypeDefaults {
  const ObjectTypeDefaults({
    this.visiblePropertyIds,
    this.propertyOrder,
    this.openMode,
    this.bodyTemplate,
  });

  final List<int>? visiblePropertyIds;
  final List<int>? propertyOrder;
  final ObjectOpenMode? openMode;
  final ObjectBodyDocument? bodyTemplate;

  bool get hasOverrides =>
      visiblePropertyIds != null ||
      propertyOrder != null ||
      openMode != null ||
      bodyTemplate != null;

  factory ObjectTypeDefaults.fromJson(dynamic value) {
    if (value is! Map) {
      throw const FormatException('ObjectType defaults must be a JSON object.');
    }

    List<int>? readIds(String key) {
      final raw = value[key];
      if (raw == null) return null;
      if (raw is! List) {
        throw FormatException('$key must be a list.');
      }
      final ids = <int>[];
      for (final item in raw) {
        final id = item is int ? item : int.tryParse('$item');
        if (id == null) {
          throw FormatException('$key entries must be integer Property ids.');
        }
        ids.add(id);
      }
      return ids;
    }

    final rawOpenMode = value['openMode'];
    ObjectOpenMode? openMode;
    if (rawOpenMode != null) {
      final name = '$rawOpenMode';
      openMode = ObjectOpenMode.values
          .where((mode) => mode.name == name)
          .firstOrNull;
      if (openMode == null) {
        throw FormatException('Unknown Object open mode: $name');
      }
    }

    final bodyTemplate = value.containsKey('bodyTemplate')
        ? ObjectBodyDocument.fromJson(value['bodyTemplate'])
        : null;

    return ObjectTypeDefaults(
      visiblePropertyIds: readIds('visiblePropertyIds'),
      propertyOrder: readIds('propertyOrder'),
      openMode: openMode,
      bodyTemplate: bodyTemplate,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (visiblePropertyIds != null)
          'visiblePropertyIds': visiblePropertyIds,
        if (propertyOrder != null) 'propertyOrder': propertyOrder,
        if (openMode != null) 'openMode': openMode!.name,
        if (bodyTemplate != null) 'bodyTemplate': bodyTemplate!.toJson(),
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
