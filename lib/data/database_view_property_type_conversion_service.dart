import '../domain/object_model.dart';
import 'object_store.dart';

enum PropertyTypeConversionMode {
  noChange,
  preserveStoredValues,
  transformStoredValues,
  requiresExplicitChoice,
  requiresMigration,
  incompatible,
}

class PropertyTypeConversionImpact {
  const PropertyTypeConversionImpact({
    required this.property,
    required this.nextType,
    required this.mode,
    required this.objectsWithStoredValue,
    this.explicitChoiceOptions = const <int, List<String>>{},
    this.objectsRequiringMigration = const <int>[],
  });

  final ObjectPropertyDefinition property;
  final ObjectPropertyType nextType;
  final PropertyTypeConversionMode mode;
  final int objectsWithStoredValue;

  /// Per-Object values from which the user must explicitly choose before a
  /// narrowing conversion can proceed. Today this is used by MultiSelect ->
  /// Select; keeping the choice payload in preflight avoids UI re-parsing raw
  /// values independently from the conversion contract.
  final Map<int, List<String>> explicitChoiceOptions;
  final List<int> objectsRequiringMigration;

  List<int> get objectsRequiringChoice =>
      List<int>.unmodifiable(explicitChoiceOptions.keys);

  bool get hasStoredValues => objectsWithStoredValue > 0;
  bool get canApplyWithoutUserValueDecision => switch (mode) {
        PropertyTypeConversionMode.noChange ||
        PropertyTypeConversionMode.preserveStoredValues ||
        PropertyTypeConversionMode.transformStoredValues => true,
        PropertyTypeConversionMode.requiresExplicitChoice ||
        PropertyTypeConversionMode.requiresMigration ||
        PropertyTypeConversionMode.incompatible => false,
      };
}

/// Read-only preflight for user-owned Value Property type changes.
///
/// This service deliberately does not mutate Property schema or Object values.
/// It only classifies conversions whose storage/value semantics are already
/// unambiguous. Relation and computed schema changes stay outside this Value
/// conversion path.
class DatabaseViewPropertyTypeConversionService {
  const DatabaseViewPropertyTypeConversionService(this.objectStore);

  final ObjectStore objectStore;

  Future<PropertyTypeConversionImpact> inspectChange({
    required int objectTypeId,
    required int propertyId,
    required ObjectPropertyType nextType,
  }) async {
    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'ObjectType does not exist.',
      );
    }
    if (objectType.kind == ObjectTypeKind.system) {
      throw StateError('System ObjectType Properties cannot be retyped by users.');
    }

    ObjectPropertyDefinition? found;
    for (final candidate in objectType.properties) {
      if (candidate.id == propertyId) {
        found = candidate;
        break;
      }
    }
    if (found == null) {
      throw ArgumentError.value(
        propertyId,
        'propertyId',
        'Property does not belong to the ObjectType.',
      );
    }
    final property = found;
    if (!property.isValue || _isManagedValueType(property.type)) {
      throw StateError('Only user-editable Value Properties can use Value type conversion.');
    }

    final objects = await objectStore.listObjects(objectTypeId);
    final stored = objects
        .where((object) => object.values.containsKey(property.id))
        .toList(growable: false);

    if (nextType == property.type) {
      return _impact(
        property: property,
        nextType: nextType,
        mode: PropertyTypeConversionMode.noChange,
        storedCount: stored.length,
      );
    }
    if (!_isUserValueType(nextType)) {
      return _impact(
        property: property,
        nextType: nextType,
        mode: PropertyTypeConversionMode.incompatible,
        storedCount: stored.length,
      );
    }

    final current = property.type;
    if (_preservesStorageWithoutNarrowing(current, nextType)) {
      final invalid = stored
          .where(
            (object) =>
                !_matchesPreservedShape(current, object.values[property.id]),
          )
          .map((object) => object.id)
          .toList(growable: false);
      return _impact(
        property: property,
        nextType: nextType,
        mode: invalid.isEmpty
            ? PropertyTypeConversionMode.preserveStoredValues
            : PropertyTypeConversionMode.requiresMigration,
        storedCount: stored.length,
        migration: invalid,
      );
    }

    if (current == ObjectPropertyType.select &&
        nextType == ObjectPropertyType.multiSelect) {
      final invalid = stored
          .where((object) {
            final value = object.values[property.id];
            return value != null && value is! String;
          })
          .map((object) => object.id)
          .toList(growable: false);
      return _impact(
        property: property,
        nextType: nextType,
        mode: invalid.isEmpty
            ? PropertyTypeConversionMode.transformStoredValues
            : PropertyTypeConversionMode.requiresMigration,
        storedCount: stored.length,
        migration: invalid,
      );
    }

    if (current == ObjectPropertyType.multiSelect &&
        nextType == ObjectPropertyType.select) {
      final choices = <int, List<String>>{};
      final invalid = <int>[];
      for (final object in stored) {
        final value = object.values[property.id];
        if (value == null) continue;
        if (value is! List || value.any((item) => item is! String)) {
          invalid.add(object.id);
          continue;
        }
        final seen = <String>{};
        final nonEmpty = value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty && seen.add(item))
            .toList(growable: false);
        if (nonEmpty.length > 1) {
          choices[object.id] = List<String>.unmodifiable(nonEmpty);
        }
      }
      final mode = invalid.isNotEmpty
          ? PropertyTypeConversionMode.requiresMigration
          : choices.isNotEmpty
              ? PropertyTypeConversionMode.requiresExplicitChoice
              : PropertyTypeConversionMode.transformStoredValues;
      return _impact(
        property: property,
        nextType: nextType,
        mode: mode,
        storedCount: stored.length,
        choiceOptions: choices,
        migration: invalid,
      );
    }

    if (current == ObjectPropertyType.number &&
        nextType == ObjectPropertyType.rating) {
      final invalid = stored
          .where((object) => !_isRatingCompatible(object.values[property.id]))
          .map((object) => object.id)
          .toList(growable: false);
      return _impact(
        property: property,
        nextType: nextType,
        mode: invalid.isEmpty
            ? PropertyTypeConversionMode.transformStoredValues
            : PropertyTypeConversionMode.requiresMigration,
        storedCount: stored.length,
        migration: invalid,
      );
    }

    return _impact(
      property: property,
      nextType: nextType,
      mode: stored.isEmpty
          ? PropertyTypeConversionMode.transformStoredValues
          : PropertyTypeConversionMode.requiresMigration,
      storedCount: stored.length,
      migration: stored.map((object) => object.id).toList(growable: false),
    );
  }

  bool _isManagedValueType(ObjectPropertyType type) => switch (type) {
        ObjectPropertyType.title ||
        ObjectPropertyType.createdTime ||
        ObjectPropertyType.updatedTime ||
        ObjectPropertyType.image ||
        ObjectPropertyType.file => true,
        _ => false,
      };

  bool _isUserValueType(ObjectPropertyType type) => switch (type) {
        ObjectPropertyType.text ||
        ObjectPropertyType.number ||
        ObjectPropertyType.checkbox ||
        ObjectPropertyType.date ||
        ObjectPropertyType.url ||
        ObjectPropertyType.select ||
        ObjectPropertyType.multiSelect ||
        ObjectPropertyType.rating => true,
        _ => false,
      };

  bool _preservesStorageWithoutNarrowing(
    ObjectPropertyType current,
    ObjectPropertyType next,
  ) =>
      (next == ObjectPropertyType.text &&
          (current == ObjectPropertyType.url ||
              current == ObjectPropertyType.select ||
              current == ObjectPropertyType.date)) ||
      (current == ObjectPropertyType.rating && next == ObjectPropertyType.number);

  bool _matchesPreservedShape(ObjectPropertyType current, dynamic value) {
    if (value == null) return true;
    return switch (current) {
      ObjectPropertyType.url ||
      ObjectPropertyType.select ||
      ObjectPropertyType.date => value is String,
      ObjectPropertyType.rating => value is num,
      _ => false,
    };
  }

  bool _isRatingCompatible(dynamic value) {
    if (value == null) return true;
    if (value is! num || !value.isFinite) return false;
    if (value < 0 || value > 5) return false;
    return value == value.roundToDouble();
  }

  PropertyTypeConversionImpact _impact({
    required ObjectPropertyDefinition property,
    required ObjectPropertyType nextType,
    required PropertyTypeConversionMode mode,
    required int storedCount,
    Map<int, List<String>> choiceOptions = const <int, List<String>>{},
    List<int> migration = const <int>[],
  }) =>
      PropertyTypeConversionImpact(
        property: property,
        nextType: nextType,
        mode: mode,
        objectsWithStoredValue: storedCount,
        explicitChoiceOptions: Map<int, List<String>>.unmodifiable(
          choiceOptions.map(
            (objectId, options) =>
                MapEntry(objectId, List<String>.unmodifiable(options)),
          ),
        ),
        objectsRequiringMigration: List<int>.unmodifiable(migration),
      );
}
