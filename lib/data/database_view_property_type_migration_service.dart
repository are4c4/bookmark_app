import '../domain/object_model.dart';
import 'database_view_property_type_conversion_service.dart';
import 'generic_database_store.dart';
import 'object_store.dart';

class PropertyTypeMigrationResult {
  const PropertyTypeMigrationResult({
    required this.property,
    required this.transformedObjectCount,
  });

  final ObjectPropertyDefinition property;
  final int transformedObjectCount;
}

/// Applies only Value Property type changes already proven safe by the
/// read-only [DatabaseViewPropertyTypeConversionService] preflight.
///
/// The preflight is deliberately repeated inside the same database transaction
/// as the schema/value writes. A caller cannot inspect one state and later apply
/// against different data. Ambiguous narrowing requires an explicit per-Object
/// choice; malformed, incompatible, or otherwise migration-required values fail
/// closed without changing either schema or data.
class DatabaseViewPropertyTypeMigrationService {
  const DatabaseViewPropertyTypeMigrationService({
    required this.genericStore,
    required this.objectStore,
  });

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;

  Future<PropertyTypeMigrationResult> applyChange({
    required int objectTypeId,
    required int propertyId,
    required ObjectPropertyType nextType,
    Map<int, String> multiSelectToSelectChoices = const <int, String>{},
  }) {
    return genericStore.database.transaction(() async {
      final preflight = DatabaseViewPropertyTypeConversionService(objectStore);
      final impact = await preflight.inspectChange(
        objectTypeId: objectTypeId,
        propertyId: propertyId,
        nextType: nextType,
      );

      switch (impact.mode) {
        case PropertyTypeConversionMode.requiresMigration:
          throw StateError(
            'Property values require an explicit migration before this type change can be applied.',
          );
        case PropertyTypeConversionMode.incompatible:
          throw StateError(
            'This Property type change is not supported by the Value migration path.',
          );
        case PropertyTypeConversionMode.noChange:
          if (multiSelectToSelectChoices.isNotEmpty) {
            throw ArgumentError.value(
              multiSelectToSelectChoices,
              'multiSelectToSelectChoices',
              'No choices are accepted when the Property type does not change.',
            );
          }
          return PropertyTypeMigrationResult(
            property: impact.property,
            transformedObjectCount: 0,
          );
        case PropertyTypeConversionMode.preserveStoredValues:
        case PropertyTypeConversionMode.transformStoredValues:
        case PropertyTypeConversionMode.requiresExplicitChoice:
          break;
      }

      final source = impact.property;
      final requiresChoices = impact.objectsRequiringChoice.toSet();
      _validateChoiceKeys(
        requiredObjectIds: requiresChoices,
        choices: multiSelectToSelectChoices,
      );

      final objects = await objectStore.listObjects(objectTypeId);
      var transformedObjectCount = 0;
      if (source.type == ObjectPropertyType.select &&
          nextType == ObjectPropertyType.multiSelect) {
        for (final object in objects) {
          if (!object.values.containsKey(propertyId)) continue;
          final current = object.values[propertyId];
          final nextValue = current == null ? null : <String>[current as String];
          await objectStore.setPropertyValue(
            objectId: object.id,
            property: source,
            value: nextValue,
          );
          transformedObjectCount++;
        }
      } else if (source.type == ObjectPropertyType.multiSelect &&
          nextType == ObjectPropertyType.select) {
        for (final object in objects) {
          if (!object.values.containsKey(propertyId)) continue;
          final current = object.values[propertyId];
          final nextValue = _selectValueFor(
            objectId: object.id,
            current: current,
            explicitChoice: multiSelectToSelectChoices[object.id],
          );
          await objectStore.setPropertyValue(
            objectId: object.id,
            property: source,
            value: nextValue,
          );
          transformedObjectCount++;
        }
      } else if (source.type == ObjectPropertyType.number &&
          nextType == ObjectPropertyType.rating) {
        for (final object in objects) {
          if (!object.values.containsKey(propertyId)) continue;
          final current = object.values[propertyId];
          final nextValue = current == null ? null : (current as num).toInt();
          await objectStore.setPropertyValue(
            objectId: object.id,
            property: source,
            value: nextValue,
          );
          transformedObjectCount++;
        }
      } else if (multiSelectToSelectChoices.isNotEmpty) {
        throw ArgumentError.value(
          multiSelectToSelectChoices,
          'multiSelectToSelectChoices',
          'Explicit choices are only valid for MultiSelect to Select narrowing.',
        );
      }

      final records = await genericStore.listProperties(objectTypeId);
      GenericPropertyRecord? rawProperty;
      for (final candidate in records) {
        if (candidate.id == propertyId) {
          rawProperty = candidate;
          break;
        }
      }
      if (rawProperty == null) {
        throw StateError('Property disappeared while applying its type migration.');
      }
      if (rawProperty.type != source.storageType) {
        throw StateError('Property schema changed while applying its type migration.');
      }

      await genericStore.updateProperty(
        GenericPropertyRecord(
          id: rawProperty.id,
          databaseId: rawProperty.databaseId,
          name: rawProperty.name,
          type: nextType.storageType,
          config: _configForNextType(rawProperty.config, nextType),
          sortOrder: rawProperty.sortOrder,
        ),
      );

      final refreshed = await objectStore.getObjectType(objectTypeId);
      if (refreshed == null) {
        throw StateError('ObjectType disappeared while applying its type migration.');
      }
      final migrated = refreshed.properties
          .where((property) => property.id == propertyId)
          .firstOrNull;
      if (migrated == null || migrated.type != nextType) {
        throw StateError('Property type migration did not persist the requested schema.');
      }

      return PropertyTypeMigrationResult(
        property: migrated,
        transformedObjectCount: transformedObjectCount,
      );
    });
  }

  void _validateChoiceKeys({
    required Set<int> requiredObjectIds,
    required Map<int, String> choices,
  }) {
    final supplied = choices.keys.toSet();
    if (supplied.length != requiredObjectIds.length ||
        !supplied.containsAll(requiredObjectIds)) {
      throw ArgumentError.value(
        choices,
        'multiSelectToSelectChoices',
        'Explicit choices must be supplied for exactly every ambiguous Object.',
      );
    }
  }

  String? _selectValueFor({
    required int objectId,
    required dynamic current,
    required String? explicitChoice,
  }) {
    if (current == null) return null;
    final values = (current as List)
        .cast<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (values.isEmpty) return null;
    if (values.length == 1) {
      if (explicitChoice != null) {
        throw ArgumentError.value(
          explicitChoice,
          'multiSelectToSelectChoices[$objectId]',
          'A non-ambiguous Object must not receive an explicit choice.',
        );
      }
      return values.single;
    }

    final normalizedChoice = explicitChoice?.trim();
    if (normalizedChoice == null || !values.contains(normalizedChoice)) {
      throw ArgumentError.value(
        explicitChoice,
        'multiSelectToSelectChoices[$objectId]',
        'Choice must be one of the Object values being narrowed.',
      );
    }
    return normalizedChoice;
  }

  Map<String, dynamic> _configForNextType(
    Map<String, dynamic> current,
    ObjectPropertyType nextType,
  ) {
    final next = <String, dynamic>{...current};
    if (nextType != ObjectPropertyType.select &&
        nextType != ObjectPropertyType.multiSelect) {
      next.remove('options');
    }
    return next;
  }
}
