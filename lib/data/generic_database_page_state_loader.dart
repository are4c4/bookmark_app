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
  final GenericDatabaseStore genericStore;
  final ObjectComputedValueStore computedStore;
  final GenericDatabaseCreateModeResolver createModeForObjectType;

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

    final objectTypes = await genericStore.listAllDatabases(workspaceId);
    final recordsByType = <int, List<GenericRecord>>{};
    for (final relatedType in objectTypes) {
      recordsByType[relatedType.id] =
          await genericStore.listRecords(relatedType.id);
    }

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
          } catch (_) {
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
      objectTypes: objectTypes,
      recordsByType: recordsByType,
      computedValues: computedValues,
      createMode: createMode,
    );
  }
}
