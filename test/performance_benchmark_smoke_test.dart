import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/performance_benchmark.dart' as benchmark;

void main() {
  test(
    'benchmark uses production boundaries and emits stable report shape',
    () async {
      final requestedProfile =
          Platform.environment['PERFORMANCE_BENCHMARK_PROFILE'];
      if (requestedProfile != null) {
        await _runWorkflowBenchmark(requestedProfile);
        return;
      }

      final report = await benchmark.runPerformanceBenchmark(
        profile: benchmark.PerformanceBenchmarkProfile.small,
        sourceSha: 'smoke-test-sha',
        warmups: 0,
        samples: 1,
      );

      expect(report.profile, benchmark.PerformanceBenchmarkProfile.small);
      expect(report.sourceSha, 'smoke-test-sha');
      expect(report.warmups, 0);
      expect(report.samples, 1);
      expect(
        report.scenarios.map((scenario) => scenario.name).toList(),
        _scenarioNames,
      );
      for (final scenario in report.scenarios) {
        expect(scenario.samplesMicros, hasLength(1));
        expect(scenario.samplesMicros.single, greaterThanOrEqualTo(0));
      }

      final json = report.toJson();
      expect(json['schemaVersion'], 1);
      expect(json['profile'], 'small');
      expect(json['sourceSha'], 'smoke-test-sha');
      expect(json['warmups'], 0);
      expect(json['samples'], 1);
      expect(json['fixture'], <String, Object?>{
        'primaryObjects': 20,
        'relationTargets': 10,
      });
      expect(json['runtime'], isA<Map<String, Object?>>());
      expect(json['scenarios'], isA<List<Map<String, Object?>>>());

      final markdown = report.toMarkdown();
      expect(markdown, contains('Source SHA: `smoke-test-sha`'));
      expect(markdown, contains('Profile: `small`'));
      for (final scenarioName in _scenarioNames) {
        expect(markdown, contains(scenarioName));
      }
      expect(markdown, contains('Advisory only'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _runWorkflowBenchmark(String profileName) async {
  final jsonPath = Platform.environment['PERFORMANCE_BENCHMARK_JSON_PATH'];
  final markdownPath =
      Platform.environment['PERFORMANCE_BENCHMARK_MARKDOWN_PATH'];
  if (jsonPath == null || markdownPath == null) {
    throw StateError(
      'Workflow benchmark requires JSON and Markdown output paths.',
    );
  }

  final sourceSha =
      Platform.environment['PERFORMANCE_BENCHMARK_SOURCE_SHA'] ?? 'unknown';
  final warmups = Platform.environment['PERFORMANCE_BENCHMARK_WARMUPS'] ?? '1';
  final samples = Platform.environment['PERFORMANCE_BENCHMARK_SAMPLES'] ?? '5';

  await benchmark.main(<String>[
    '--profile=$profileName',
    '--source-sha=$sourceSha',
    '--warmups=$warmups',
    '--samples=$samples',
    '--json=$jsonPath',
    '--markdown=$markdownPath',
  ]);

  final profile = benchmark.PerformanceBenchmarkProfile.values.singleWhere(
    (candidate) => candidate.name == profileName,
  );
  final decoded = jsonDecode(await File(jsonPath).readAsString());
  expect(decoded, isA<Map<String, dynamic>>());
  final json = decoded as Map<String, dynamic>;
  expect(json['schemaVersion'], 1);
  expect(json['profile'], profileName);
  expect(json['sourceSha'], sourceSha);
  expect(json['warmups'], int.parse(warmups));
  expect(json['samples'], int.parse(samples));
  expect(json['fixture'], <String, Object?>{
    'primaryObjects': profile.primaryObjects,
    'relationTargets': profile.relationTargets,
  });
  expect(json['runtime'], isA<Map<String, dynamic>>());

  final scenarios = (json['scenarios'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  expect(
    scenarios.map((scenario) => scenario['name']).toList(),
    _scenarioNames,
  );
  for (final scenario in scenarios) {
    expect(scenario['samples'], isA<List<dynamic>>());
    expect((scenario['samples'] as List<dynamic>).length, int.parse(samples));
  }

  final markdown = await File(markdownPath).readAsString();
  expect(markdown, contains('Source SHA: `$sourceSha`'));
  expect(markdown, contains('Profile: `$profileName`'));
  for (final scenarioName in _scenarioNames) {
    expect(markdown, contains(scenarioName));
  }
  expect(markdown, contains('Advisory only'));
}

const _scenarioNames = <String>[
  'generic-database-page-load',
  'canonical-search-prepare-healthy',
  'canonical-object-search',
  'canonical-search-rebuild',
  'relation-picker-load',
];
