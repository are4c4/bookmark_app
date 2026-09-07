import '../domain/object_model.dart';
import 'database_view_property_type_conversion_service.dart';
import 'database_view_property_type_migration_service.dart';

/// Explicit destructive fallback for Value Property type changes whose stored
/// values cannot be migrated safely.
///
/// The caller must obtain an explicit user decision before invoking this method.
/// Values are cleared and the existing safe migration path is re-run inside one
/// outer transaction, so any later schema/preflight failure restores both the
/// old values and old Property type.
extension DatabaseViewPropertyClearMigration
    on DatabaseViewPropertyTypeMigrationService {
  Future<PropertyTypeMigrationResult> applyChangeClearingStoredValues({
    required int objectTypeId,
    required int propertyId,
    required ObjectPropertyType nextType,
  }) {
    return genericStore.database.transaction(() async {
      final preflight = DatabaseViewPropertyTypeConversionService(objectStore);
      final impact = await preflight.inspectChange(
        objectTypeId: objectTypeId,
        propertyId: propertyId,
        nextType: nextType,
      );

      if (impact.mode != PropertyTypeConversionMode.requiresMigration &&
          impact.mode != PropertyTypeConversionMode.incompatible) {
        throw StateError(
          'Clearing stored values is only valid for a migration-blocked Value Property type change.',
        );
      }

      final source = impact.property;
      if (!source.isValue) {
        throw StateError('Only Value Properties can use clear-values migration.');
      }

      final objects = await objectStore.listObjects(objectTypeId);
      var clearedObjectCount = 0;
      for (final object in objects) {
        if (!object.values.containsKey(propertyId) ||
            object.values[propertyId] == null) {
          continue;
        }
        await objectStore.setPropertyValue(
          objectId: object.id,
          property: source,
          value: null,
        );
        clearedObjectCount++;
      }

      final migrated = await applyChange(
        objectTypeId: objectTypeId,
        propertyId: propertyId,
        nextType: nextType,
      );
      return PropertyTypeMigrationResult(
        property: migrated.property,
        transformedObjectCount: clearedObjectCount,
      );
    });
  }
}
