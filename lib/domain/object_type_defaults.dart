enum ObjectOpenMode {
  sidePeek,
  centerPeek,
  fullPage,
}

/// Reusable defaults owned by an ObjectType.
///
/// Database and View layers may override these values, but those overrides are
/// intentionally not stored here. This keeps ObjectType defaults reusable while
/// preserving the resolution order `View > Database > ObjectType > app`.
class ObjectTypeDefaults {
  const ObjectTypeDefaults({
    this.visiblePropertyIds,
    this.propertyOrder,
    this.openMode,
  });

  final List<int>? visiblePropertyIds;
  final List<int>? propertyOrder;
  final ObjectOpenMode? openMode;

  bool get hasOverrides =>
      visiblePropertyIds != null || propertyOrder != null || openMode != null;

  factory ObjectTypeDefaults.fromJson(dynamic value) {
    if (value is! Map) return const ObjectTypeDefaults();

    List<int>? readIds(String key) {
      final raw = value[key];
      if (raw == null) return null;
      if (raw is! List) {
        throw FormatException('$key must be a list.');
      }
      return raw
          .map((item) => item is int ? item : int.tryParse('$item'))
          .whereType<int>()
          .toList(growable: false);
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

    return ObjectTypeDefaults(
      visiblePropertyIds: readIds('visiblePropertyIds'),
      propertyOrder: readIds('propertyOrder'),
      openMode: openMode,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (visiblePropertyIds != null)
          'visiblePropertyIds': visiblePropertyIds,
        if (propertyOrder != null) 'propertyOrder': propertyOrder,
        if (openMode != null) 'openMode': openMode!.name,
      };
}

class ResolvedObjectTypeDefaults {
  const ResolvedObjectTypeDefaults({
    required this.visiblePropertyIds,
    required this.propertyOrder,
    required this.openMode,
  });

  final List<int> visiblePropertyIds;
  final List<int> propertyOrder;
  final ObjectOpenMode openMode;
}

class ObjectTypeDefaultsResolver {
  const ObjectTypeDefaultsResolver();

  ResolvedObjectTypeDefaults resolve({
    required ObjectTypeDefaults appFallback,
    ObjectTypeDefaults? objectTypeDefaults,
  }) {
    final type = objectTypeDefaults ?? const ObjectTypeDefaults();
    final fallbackVisible = appFallback.visiblePropertyIds ?? const <int>[];
    final fallbackOrder = appFallback.propertyOrder ?? const <int>[];
    final fallbackOpenMode = appFallback.openMode ?? ObjectOpenMode.sidePeek;

    return ResolvedObjectTypeDefaults(
      visiblePropertyIds: List<int>.unmodifiable(
        type.visiblePropertyIds ?? fallbackVisible,
      ),
      propertyOrder: List<int>.unmodifiable(
        type.propertyOrder ?? fallbackOrder,
      ),
      openMode: type.openMode ?? fallbackOpenMode,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
