import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_page_state_loader.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';

/// Repeatable structural probe for Issue #225's GenericDatabasePage reload path.
///
/// Run from the repository root:
///
///   dart run tool/generic_database_page_performance_probe.dart
///   dart run tool/generic_database_page_performance_probe.dart 100:5 1000:20
///
/// Each argument is `objects:relatedTypes`. The first related ObjectType is an
/// actual Relation target; remaining related ObjectTypes are deliberately
/// unrelated to the page. This keeps the probe sensitive to accidental
/// reintroduction of workspace-wide record fan-out while measuring the
/// production [GenericDatabasePageStateLoader] path.
Future<void> main(List<String> arguments) async {
  final scenarios = arguments.isEmpty
      ? const [
          _Scenario(objects: 100, relatedTypes: 5),
          _Scenario(objects: 1000, relatedTypes: 20),
          _Scenario(objects: 5000, relatedTypes: 50),
        ]
      : arguments.map(_Scenario.parse).toList(growable: false);

  for (final scenario in scenarios) {
    await _runScenario(scenario);
  }
}

Future<void> _runScenario(_Scenario scenario) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  try {
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final computedStore = ObjectComputedValueStore(objectStore);
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final pageLoader = GenericDatabaseCollectionPageLoader(
      genericStore: genericStore,
      collectionResolver: DatabaseCollectionResolver(
        collectionStore: collectionStore,
        objectStore: objectStore,
      ),
    );
    final loader = GenericDatabasePageStateLoader(
      pageLoader: pageLoader,
      genericStore: genericStore,
      computedStore: computedStore,
      createModeForObjectType: (_) async => GenericDatabaseCreateMode.generic,
    );

    final seedWatch = Stopwatch()..start();
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Benchmark records',
    );
    final valuePropertyId = await objectStore.createProperty(
      objectTypeId: databaseId,
      name: 'Value',
      type: ObjectPropertyType.number,
    );
    await computedStore.createFormulaProperty(
      objectTypeId: databaseId,
      name: 'Double',
      expression: '{$valuePropertyId} * 2',
    );
    final objectType = (await objectStore.getObjectType(databaseId))!;
    final valueProperty = objectType.properties.singleWhere(
      (property) => property.id == valuePropertyId,
    );

    for (var index = 0; index < scenario.objects; index++) {
      final objectId = await objectStore.createObject(
        objectTypeId: databaseId,
        title: 'Record $index',
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: valueProperty,
        value: index,
      );
    }

    int? relationTargetObjectTypeId;
    for (var index = 0; index < scenario.relatedTypes; index++) {
      final relatedTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Related type $index',
      );
      await objectStore.createObject(
        objectTypeId: relatedTypeId,
        title: 'Related record $index',
      );
      relationTargetObjectTypeId ??= relatedTypeId;
    }
    if (relationTargetObjectTypeId != null) {
      await objectStore.createRelationProperty(
        objectTypeId: databaseId,
        name: 'Probe relation',
        targetObjectTypeId: relationTargetObjectTypeId,
      );
    }
    seedWatch.stop();

    final firstLoadWatch = Stopwatch()..start();
    final first = await loader.load(
      databaseId: databaseId,
      workspaceId: workspaceId,
    );
    firstLoadWatch.stop();

    final secondLoadWatch = Stopwatch()..start();
    final second = await loader.load(
      databaseId: databaseId,
      workspaceId: workspaceId,
    );
    secondLoadWatch.stop();

    final expectedRecordCatalogs = scenario.relatedTypes == 0 ? 0 : 1;
    if (first.objects.length != scenario.objects ||
        second.objects.length != scenario.objects ||
        first.objectTypes.length != scenario.relatedTypes + 1 ||
        second.objectTypes.length != scenario.relatedTypes + 1 ||
        first.recordsByType.length != expectedRecordCatalogs ||
        second.recordsByType.length != expectedRecordCatalogs ||
        second.computedValues.length != scenario.objects) {
      throw StateError('Probe projection did not match seeded scenario.');
    }

    print(
      '${scenario.objects} objects / ${scenario.relatedTypes} related types seeded: '
      'seed=${_milliseconds(seedWatch)}ms, '
      'load1=${_milliseconds(firstLoadWatch)}ms, '
      'load2=${_milliseconds(secondLoadWatch)}ms, '
      'recordCatalogFanout=${second.recordsByType.length}, '
      'computedObjects=${second.computedValues.length}',
    );
  } finally {
    await database.close();
  }
}

String _milliseconds(Stopwatch watch) =>
    (watch.elapsedMicroseconds / 1000).toStringAsFixed(2);

class _Scenario {
  const _Scenario({required this.objects, required this.relatedTypes});

  final int objects;
  final int relatedTypes;

  factory _Scenario.parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      throw FormatException(
        'Invalid scenario "$value". Expected objects:relatedTypes.',
      );
    }
    final objects = int.tryParse(parts[0]);
    final relatedTypes = int.tryParse(parts[1]);
    if (objects == null ||
        objects <= 0 ||
        relatedTypes == null ||
        relatedTypes < 0) {
      throw FormatException(
        'Invalid scenario "$value". Counts must be objects>0 and relatedTypes>=0.',
      );
    }
    return _Scenario(objects: objects, relatedTypes: relatedTypes);
  }
}
