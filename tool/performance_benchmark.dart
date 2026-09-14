import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_page_state_loader.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:drift/native.dart';

enum PerformanceBenchmarkProfile {
  small(primaryObjects: 20, relationTargets: 10),
  medium(primaryObjects: 500, relationTargets: 250),
  large(primaryObjects: 2500, relationTargets: 1000);

  const PerformanceBenchmarkProfile({
    required this.primaryObjects,
    required this.relationTargets,
  });

  final int primaryObjects;
  final int relationTargets;
}

class BenchmarkScenarioResult {
  const BenchmarkScenarioResult({
    required this.name,
    required this.samplesMicros,
  });

  final String name;
  final List<int> samplesMicros;

  Map<String, Object?> toJson() {
    final sorted = [...samplesMicros]..sort();
    return <String, Object?>{
      'name': name,
      'unit': 'microseconds',
      'samples': samplesMicros,
      'summary': <String, Object?>{
        'min': sorted.first,
        'median': _median(sorted),
        'p95': _percentile(sorted, 0.95),
        'max': sorted.last,
      },
    };
  }

  String toMarkdownRow() {
    final sorted = [...samplesMicros]..sort();
    return '| $name | ${_milliseconds(_median(sorted))} | '
        '${_milliseconds(_percentile(sorted, 0.95))} | '
        '${_milliseconds(sorted.first)} | ${_milliseconds(sorted.last)} |';
  }
}

class PerformanceBenchmarkReport {
  const PerformanceBenchmarkReport({
    required this.sourceSha,
    required this.profile,
    required this.warmups,
    required this.samples,
    required this.scenarios,
  });

  final String sourceSha;
  final PerformanceBenchmarkProfile profile;
  final int warmups;
  final int samples;
  final List<BenchmarkScenarioResult> scenarios;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'sourceSha': sourceSha,
    'profile': profile.name,
    'warmups': warmups,
    'samples': samples,
    'fixture': <String, Object?>{
      'primaryObjects': profile.primaryObjects,
      'relationTargets': profile.relationTargets,
    },
    'runtime': <String, Object?>{
      'dartVersion': Platform.version,
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
    },
    'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
  };

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Performance benchmark')
      ..writeln()
      ..writeln('- Source SHA: `$sourceSha`')
      ..writeln('- Profile: `${profile.name}`')
      ..writeln(
        '- Fixture: ${profile.primaryObjects} primary Objects / '
        '${profile.relationTargets} Relation targets',
      )
      ..writeln('- Warmups: $warmups')
      ..writeln('- Samples per scenario: $samples')
      ..writeln()
      ..writeln('| Scenario | Median (ms) | p95 (ms) | Min (ms) | Max (ms) |')
      ..writeln('| --- | ---: | ---: | ---: | ---: |');
    for (final scenario in scenarios) {
      buffer.writeln(scenario.toMarkdownRow());
    }
    buffer
      ..writeln()
      ..writeln(
        '> Advisory only: compare repeated runs on equivalent runner/runtime '
        'profiles before promoting any metric to a blocking budget.',
      );
    return buffer.toString();
  }
}

Future<PerformanceBenchmarkReport> runPerformanceBenchmark({
  required PerformanceBenchmarkProfile profile,
  required String sourceSha,
  int warmups = 1,
  int samples = 5,
}) async {
  if (warmups < 0) {
    throw ArgumentError.value(warmups, 'warmups', 'Must be non-negative.');
  }
  if (samples <= 0) {
    throw ArgumentError.value(samples, 'samples', 'Must be positive.');
  }

  final fixture = await _BenchmarkFixture.create(profile);
  try {
    await fixture.search.rebuildWorkspace(fixture.workspaceId);

    final pageLoadSamples = await _measure(
      warmups: warmups,
      samples: samples,
      operation: () async {
        final state = await fixture.pageLoader.load(
          databaseId: fixture.primaryObjectTypeId,
          workspaceId: fixture.workspaceId,
        );
        if (state.objects.length != profile.primaryObjects ||
            state.computedValues.length != profile.primaryObjects) {
          throw StateError(
            'Database page benchmark loaded an unexpected fixture.',
          );
        }
      },
    );

    final searchSamples = await _measure(
      warmups: warmups,
      samples: samples,
      operation: () async {
        final results = await fixture.search.search(
          workspaceId: fixture.workspaceId,
          rawQuery: _BenchmarkFixture.searchNeedle,
        );
        if (results.isEmpty) {
          throw StateError('Search benchmark returned no deterministic hits.');
        }
      },
    );

    final relationPickerSamples = await _measure(
      warmups: warmups,
      samples: samples,
      operation: () async {
        final context = await fixture.relationTargets.selectionFor(
          workspaceId: fixture.workspaceId,
          sourceObjectId: fixture.relationSourceObjectId,
          property: fixture.relationProperty,
        );
        if (context.candidates.length != profile.relationTargets ||
            context.selectedObjectIds.length != fixture.selectedTargetCount) {
          throw StateError(
            'Relation picker benchmark loaded an unexpected fixture.',
          );
        }
      },
    );

    return PerformanceBenchmarkReport(
      sourceSha: sourceSha,
      profile: profile,
      warmups: warmups,
      samples: samples,
      scenarios: <BenchmarkScenarioResult>[
        BenchmarkScenarioResult(
          name: 'generic-database-page-load',
          samplesMicros: pageLoadSamples,
        ),
        BenchmarkScenarioResult(
          name: 'canonical-object-search',
          samplesMicros: searchSamples,
        ),
        BenchmarkScenarioResult(
          name: 'relation-picker-load',
          samplesMicros: relationPickerSamples,
        ),
      ],
    );
  } finally {
    await fixture.close();
  }
}

Future<void> main(List<String> arguments) async {
  final options = _BenchmarkOptions.parse(arguments);
  final report = await runPerformanceBenchmark(
    profile: options.profile,
    sourceSha: options.sourceSha,
    warmups: options.warmups,
    samples: options.samples,
  );

  final jsonText = const JsonEncoder.withIndent('  ').convert(report.toJson());
  final markdown = report.toMarkdown();
  stdout.writeln(markdown);

  if (options.jsonPath != null) {
    await _writeFile(options.jsonPath!, '$jsonText\n');
  }
  if (options.markdownPath != null) {
    await _writeFile(options.markdownPath!, markdown);
  }
}

Future<List<int>> _measure({
  required int warmups,
  required int samples,
  required Future<void> Function() operation,
}) async {
  for (var index = 0; index < warmups; index++) {
    await operation();
  }

  final timings = <int>[];
  for (var index = 0; index < samples; index++) {
    final watch = Stopwatch()..start();
    await operation();
    watch.stop();
    timings.add(watch.elapsedMicroseconds);
  }
  return List.unmodifiable(timings);
}

num _median(List<int> sorted) {
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

int _percentile(List<int> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}

String _milliseconds(num micros) => (micros / 1000).toStringAsFixed(2);

Future<void> _writeFile(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}

class _BenchmarkFixture {
  const _BenchmarkFixture({
    required this.database,
    required this.workspaceId,
    required this.primaryObjectTypeId,
    required this.relationSourceObjectId,
    required this.relationProperty,
    required this.selectedTargetCount,
    required this.pageLoader,
    required this.search,
    required this.relationTargets,
  });

  static const searchNeedle = 'benchmark-needle';

  final AppDatabase database;
  final int workspaceId;
  final int primaryObjectTypeId;
  final int relationSourceObjectId;
  final ObjectPropertyDefinition relationProperty;
  final int selectedTargetCount;
  final GenericDatabasePageStateLoader pageLoader;
  final ObjectGlobalSearchService search;
  final RelationTargetService relationTargets;

  static Future<_BenchmarkFixture> create(
    PerformanceBenchmarkProfile profile,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final computedStore = ObjectComputedValueStore(objectStore);

      final primaryObjectTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Benchmark records',
      );
      final numberPropertyId = await objectStore.createProperty(
        objectTypeId: primaryObjectTypeId,
        name: 'Value',
        type: ObjectPropertyType.number,
      );
      await computedStore.createFormulaProperty(
        objectTypeId: primaryObjectTypeId,
        name: 'Double',
        expression: '{$numberPropertyId} * 2',
      );

      final primaryType = (await objectStore.getObjectType(
        primaryObjectTypeId,
      ))!;
      final numberProperty = primaryType.properties.singleWhere(
        (property) => property.id == numberPropertyId,
      );
      final primaryObjectIds = <int>[];
      for (var index = 0; index < profile.primaryObjects; index++) {
        final objectId = await objectStore.createObject(
          objectTypeId: primaryObjectTypeId,
          title: index % 17 == 0
              ? '$searchNeedle $index'
              : 'Benchmark object $index',
        );
        primaryObjectIds.add(objectId);
        await objectStore.setPropertyValue(
          objectId: objectId,
          property: numberProperty,
          value: index,
        );
      }

      final targetObjectTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Benchmark relation targets',
      );
      final targetObjectIds = <int>[];
      for (var index = 0; index < profile.relationTargets; index++) {
        targetObjectIds.add(
          await objectStore.createObject(
            objectTypeId: targetObjectTypeId,
            title: 'Relation target $index',
          ),
        );
      }

      final relationPropertyId = await objectStore.createRelationProperty(
        objectTypeId: primaryObjectTypeId,
        name: 'Related targets',
        targetObjectTypeId: targetObjectTypeId,
      );
      final hydratedPrimaryType = (await objectStore.getObjectType(
        primaryObjectTypeId,
      ))!;
      final relationProperty = hydratedPrimaryType.properties.singleWhere(
        (property) => property.id == relationPropertyId,
      );
      final selectedTargetIds = targetObjectIds.take(3).toList(growable: false);
      await objectStore.setRelation(
        objectId: primaryObjectIds.first,
        property: relationProperty,
        targetObjectIds: selectedTargetIds,
      );

      final collectionStore = DatabaseCollectionStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final pageDataLoader = GenericDatabaseCollectionPageLoader(
        genericStore: genericStore,
        collectionResolver: DatabaseCollectionResolver(
          collectionStore: collectionStore,
          objectStore: objectStore,
        ),
      );
      final pageLoader = GenericDatabasePageStateLoader(
        pageLoader: pageDataLoader,
        genericStore: genericStore,
        computedStore: computedStore,
        createModeForObjectType: (_) async => GenericDatabaseCreateMode.generic,
      );

      return _BenchmarkFixture(
        database: database,
        workspaceId: workspaceId,
        primaryObjectTypeId: primaryObjectTypeId,
        relationSourceObjectId: primaryObjectIds.first,
        relationProperty: relationProperty,
        selectedTargetCount: selectedTargetIds.length,
        pageLoader: pageLoader,
        search: ObjectGlobalSearchService(genericStore),
        relationTargets: RelationTargetService(objectStore),
      );
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  Future<void> close() => database.close();
}

class _BenchmarkOptions {
  const _BenchmarkOptions({
    required this.profile,
    required this.sourceSha,
    required this.warmups,
    required this.samples,
    required this.jsonPath,
    required this.markdownPath,
  });

  final PerformanceBenchmarkProfile profile;
  final String sourceSha;
  final int warmups;
  final int samples;
  final String? jsonPath;
  final String? markdownPath;

  static _BenchmarkOptions parse(List<String> arguments) {
    final values = <String, String>{};
    for (final argument in arguments) {
      if (!argument.startsWith('--') || !argument.contains('=')) {
        throw FormatException('Expected --name=value, got "$argument".');
      }
      final separator = argument.indexOf('=');
      values[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }

    final profileName = values['profile'] ?? 'small';
    final profile = PerformanceBenchmarkProfile.values.where(
      (candidate) => candidate.name == profileName,
    );
    if (profile.length != 1) {
      throw FormatException('Unknown benchmark profile "$profileName".');
    }

    final sourceSha =
        values['source-sha'] ??
        Platform.environment['PERFORMANCE_BENCHMARK_SOURCE_SHA'] ??
        'local';
    final warmups = int.tryParse(values['warmups'] ?? '1');
    final samples = int.tryParse(values['samples'] ?? '5');
    if (warmups == null || warmups < 0) {
      throw FormatException('--warmups must be a non-negative integer.');
    }
    if (samples == null || samples <= 0) {
      throw FormatException('--samples must be a positive integer.');
    }

    return _BenchmarkOptions(
      profile: profile.single,
      sourceSha: sourceSha,
      warmups: warmups,
      samples: samples,
      jsonPath: values['json'],
      markdownPath: values['markdown'],
    );
  }
}
