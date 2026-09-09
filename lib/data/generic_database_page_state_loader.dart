import 'dart:io';

import '../domain/object_model.dart';
import 'database_view_gallery_cover_source_service.dart';
import 'generic_database_collection_page_data.dart';
import 'generic_database_object_create_service.dart';
import 'generic_database_store.dart';
import 'object_computed_value_store.dart';
import 'object_store.dart';
import 'relation_read_service.dart';

typedef GenericDatabaseCreateModeResolver = Future<GenericDatabaseCreateMode>
    Function(int objectTypeId);
typedef GenericDatabaseGalleryCoverSourceResolver =
    Future<List<GalleryCoverSourceOption>> Function(int objectTypeId);

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
    required this.galleryCoverSources,
    required this.createMode,
  });

  final GenericDatabaseDefinitionRecord? database;
  final AppObjectType? objectType;
  final List<AppObject> objects;
  final List<GenericPropertyRecord> properties;
  final List<GenericRecord> records;
  final List<GenericDatabaseDefinitionRecord> objectTypes;

  /// Record catalogs required by Relation rendering/editing for this page.
  ///
  /// Only ObjectTypes referenced by the current ObjectType's Relation
  /// Properties are loaded. Unrelated workspace ObjectTypes are intentionally
  /// omitted so page reload does not fan out into every record set.
  final Map<int, List<GenericRecord>> recordsByType;

  final Map<int, Map<int, dynamic>> computedValues;
  final List<GalleryCoverSourceOption> galleryCoverSources;
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
    this.galleryCoverSourcesForObjectType,
  });

  final GenericDatabaseCollectionPageLoader pageLoader;
  final GenericDatabaseStore genericStore;
  final ObjectComputedValueStore computedStore;
  final GenericDatabaseCreateModeResolver createModeForObjectType;
  final GenericDatabaseGalleryCoverSourceResolver?
      galleryCoverSourcesForObjectType;

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
    var galleryCoverSources = const <GalleryCoverSourceOption>[];
    final coverSourceResolver = galleryCoverSourcesForObjectType;
    if (objectType != null && coverSourceResolver != null) {
      try {
        galleryCoverSources = await coverSourceResolver(objectType.id);
      } catch (_) {
        galleryCoverSources = const <GalleryCoverSourceOption>[];
      }
    }

    final objectTypes = await genericStore.listAllDatabases(workspaceId);
    final availableObjectTypeIds = objectTypes.map((type) => type.id).toSet();
    final relationTargetObjectTypeIds = objectType == null
        ? const <int>[]
        : (objectType.properties
                  .where((property) => property.isRelation)
                  .map((property) => property.targetObjectTypeId)
                  .whereType<int>()
                  .where(availableObjectTypeIds.contains)
                  .toSet()
                  .toList()
              ..sort());
    final recordsByType = <int, List<GenericRecord>>{};
    for (final targetObjectTypeId in relationTargetObjectTypeIds) {
      recordsByType[targetObjectTypeId] =
          await genericStore.listRecords(targetObjectTypeId);
    }

    final records = objectType == null
        ? page?.records ?? const <GenericRecord>[]
        : await _projectRelationValues(
            objectType: objectType,
            objects: objects,
            records: page?.records ?? const <GenericRecord>[],
            availableObjectTypeIds: availableObjectTypeIds,
            recordsByType: recordsByType,
          );

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
      records: records,
      objectTypes: objectTypes,
      recordsByType: recordsByType,
      computedValues: computedValues,
      galleryCoverSources: galleryCoverSources,
      createMode: createMode,
    );
  }

  Future<List<GenericRecord>> _projectRelationValues({
    required AppObjectType objectType,
    required List<AppObject> objects,
    required List<GenericRecord> records,
    required Set<int> availableObjectTypeIds,
    required Map<int, List<GenericRecord>> recordsByType,
  }) async {
    final relationProperties = objectType.properties
        .where((property) => property.isRelation)
        .toList(growable: false);
    if (relationProperties.isEmpty || records.isEmpty) return records;

    final objectsById = <int, AppObject>{
      for (final object in objects) object.id: object,
    };
    final objectStore = ObjectStore(genericStore);
    final projected = <GenericRecord>[];

    for (final record in records) {
      final source = objectsById[record.id];
      final edges = source == null
          ? const <ObjectRelationEdge>[]
          : await objectStore.outgoingRelations(source.id);
      final edgesByProperty = <int, List<ObjectRelationEdge>>{};
      for (final edge in edges) {
        (edgesByProperty[edge.propertyId] ??= <ObjectRelationEdge>[]).add(edge);
      }

      final values = Map<int, dynamic>.from(record.values);
      for (final property in relationProperties) {
        final targetTypeId = property.targetObjectTypeId;
        var targetIds = const <int>[];
        if (source != null &&
            targetTypeId != null &&
            availableObjectTypeIds.contains(targetTypeId)) {
          final propertyEdges = edgesByProperty[property.id] ??
              const <ObjectRelationEdge>[];
          if (relationStoredValueMatchesEdges(
            source: source,
            property: property,
            edges: propertyEdges,
          )) {
            final knownTargetIds = (recordsByType[targetTypeId] ??
                    const <GenericRecord>[])
                .map((target) => target.id)
                .toSet();
            final persistedTargetIds = propertyEdges
                .map((edge) => edge.targetObjectId)
                .toList(growable: false);
            if (persistedTargetIds.every(knownTargetIds.contains)) {
              targetIds = persistedTargetIds;
            }
          }
        }
        values[property.id] = <String, dynamic>{
          'objectIds': List<int>.unmodifiable(targetIds),
        };
      }

      projected.add(
        GenericRecord(
          id: record.id,
          databaseId: record.databaseId,
          title: record.title,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
          values: Map<int, dynamic>.unmodifiable(values),
        ),
      );
    }

    return List<GenericRecord>.unmodifiable(projected);
  }
}
