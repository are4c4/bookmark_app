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
