import 'dart:io';

import '../domain/object_model.dart';
import 'generic_database_collection_page_data.dart';
import 'generic_database_object_create_service.dart';
import 'generic_database_store.dart';
import 'object_computed_value_store.dart';

typedef GenericDatabaseCreateModeResolver = Future<GenericDatabaseCreateMode>
    Function(int objectTypeId);

/// Immutable loading result consumed by `GenericDatabasePage`.
///
/// This keeps page loading/projection ownership outside the Widget while the
/// page continues to own interaction state such as selection, query and active
/// View state.
class GenericDatabasePageState {
  const GenericDatabasePageState({
    required this.database,
    required this.objectType,
    required this.objects,
    required this.properties,
    required this.records,
    required this.objectTypes,
    required this.recordsByType,
    required this.computedValues,
    required this.createMode,
  });

  final GenericDatabaseDefinitionRecord? database;
  final AppObjectType? objectType;
  final List<AppObject> objects;
  final List<GenericPropertyRecord> properties;
  final List<GenericRecord> records;

  /// Compatibility placeholders for the current shared page-state seam.
  ///
  /// `GenericDatabasePage` does not consume these projections. Keeping them
  /// empty avoids loading every ObjectType and every record set on each reload
  /// while allowing the large shared host to be simplified separately.
  final List<GenericDatabaseDefinitionRecord> objectTypes;
  final Map<int, List<GenericRecord>> recordsByType;

  final Map<int, Map<int, dynamic>> computedValues;
  final GenericDatabaseCreateMode createMode;
}

/// Loads the read/projection state required by `GenericDatabasePage`.
///
/// The Widget used to own these database reads and computed-property loops in
/// `_reload()`. Keeping them here makes the page a consumer of one coherent
/// snapshot without changing collection, ordering or fail-soft computation
/// semantics.
class GenericDatabasePageStateLoader {
  const GenericDatabasePageStateLoader({
    required this.pageLoader,
    required this.genericStore,
    required this.computedStore,
    required this.createModeForObjectType,
  });

  final GenericDatabaseCollectionPageLoader pageLoader;

  /// Retained until the shared `GenericDatabasePageServices` composition seam
  /// can remove this constructor dependency without overlapping active work.
  /// Reload no longer uses it for workspace-wide ObjectType/record fan-out.
  final GenericDatabaseStore genericStore;
  final ObjectComputedValueStore computedStore;
  final GenericDatabaseCreateModeResolver createModeForObjectType;

  static void _debugComputedProjectionFallback(StackTrace stackTrace) {
    assert(() {
      stderr.writeln(
        'GenericDatabasePageStateLoader: computed projection failed; using null.',
      );
      stderr.writeln(stackTrace);
      return true;
    }());
  }

  Future<GenericDatabasePageState> load({
    required int databaseId,
    required int workspaceId,
  }) async {
    final page = await pageLoader.load(databaseId);
    final objectType = page?.objectType;
    final objects = page?.objects ?? const <AppObject>[];
    final createMode = objectType == null
        ? GenericDatabaseCreateMode.generic
        : await createModeForObjectType(objectType.id);

    final computedValues = <int, Map<int, dynamic>>{};
    if (objectType != null) {
      final computedProperties = objectType.properties
          .where(
            (property) =>
                property.type == ObjectPropertyType.formula ||
                property.type == ObjectPropertyType.rollup,
          )
          .toList(growable: false);
      for (final object in objects) {
        for (final property in computedProperties) {
          try {
            final value = await computedStore.evaluate(
              object: object,
              property: property,
            );
            (computedValues[object.id] ??= <int, dynamic>{})[property.id] =
                value;
          } catch (_, stackTrace) {
            // One malformed computed Property must not prevent the Database page
            // from loading. Preserve the existing null projection while exposing
            // unexpected evaluation failures during development without logging
            // Object titles, Property expressions, or other user content.
            _debugComputedProjectionFallback(stackTrace);
            (computedValues[object.id] ??= <int, dynamic>{})[property.id] =
                null;
          }
        }
      }
    }

    return GenericDatabasePageState(
      database: page?.database,
      objectType: objectType,
      objects: objects,
      properties: page?.properties ?? const <GenericPropertyRecord>[],
      records: page?.records ?? const <GenericRecord>[],
      objectTypes: const <GenericDatabaseDefinitionRecord>[],
      recordsByType: const <int, List<GenericRecord>>{},
      computedValues: computedValues,
      createMode: createMode,
    );
  }
}
