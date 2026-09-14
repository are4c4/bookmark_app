import 'package:flutter_test/flutter_test.dart';

import '../tool/performance_benchmark_variance.dart';

void main() {
  test('aggregates unchanged-source benchmark spread', () {
    final report = aggregatePerformanceBenchmarkReports(<Map<String, Object?>>[
      _report(median: 100, p95: 120),
      _report(median: 110, p95: 132),
      _report(median: 90, p95: 108),
    ]);

    expect(report.sourceSha, 'same-sha');
    expect(report.profile, 'large');
    expect(report.runCount, 3);
    expect(report.scenarios, hasLength(1));

    final json = report.toJson();
    final scenarios = (json['scenarios'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final median = scenarios.single['median'] as Map<String, Object?>;
    final p95 = scenarios.single['p95'] as Map<String, Object?>;
    expect(median['min'], 90);
    expect(median['median'], 100);
    expect(median['max'], 110);
    expect(median['relativeSpreadPercent'], 20.0);
    expect(p95['relativeSpreadPercent'], 20.0);

    final markdown = report.toMarkdown();
    expect(markdown, contains('Independent runs: 3'));
    expect(markdown, contains('| scenario-a | 20.0% | 20.0% |'));
    expect(markdown, contains('Advisory only'));
  });

  test('reports zero spread for identical repeated results', () {
    final report = aggregatePerformanceBenchmarkReports(<Map<String, Object?>>[
      _report(median: 100, p95: 120),
      _report(median: 100, p95: 120),
    ]);

    final scenario =
        (report.toJson()['scenarios'] as List<Object?>).single
            as Map<String, Object?>;
    final median = scenario['median'] as Map<String, Object?>;
    expect(median['relativeSpreadPercent'], 0.0);
  });

  test('rejects mismatched provenance before comparing timings', () {
    final second = _report(median: 101, p95: 121)
      ..['sourceSha'] = 'different-sha';

    expect(
      () => aggregatePerformanceBenchmarkReports(<Map<String, Object?>>[
        _report(median: 100, p95: 120),
        second,
      ]),
      throwsFormatException,
    );
  });

  test('rejects runtime and scenario mismatches', () {
    final runtimeMismatch = _report(median: 101, p95: 121);
    (runtimeMismatch['runtime'] as Map<String, Object?>)['dartVersion'] =
        'other';
    expect(
      () => aggregatePerformanceBenchmarkReports(<Map<String, Object?>>[
        _report(median: 100, p95: 120),
        runtimeMismatch,
      ]),
      throwsFormatException,
    );

    final scenarioMismatch = _report(median: 101, p95: 121);
    final scenarios =
        scenarioMismatch['scenarios'] as List<Map<String, Object?>>;
    scenarios.single['name'] = 'scenario-b';
    expect(
      () => aggregatePerformanceBenchmarkReports(<Map<String, Object?>>[
        _report(median: 100, p95: 120),
        scenarioMismatch,
      ]),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _report({
  required num median,
  required num p95,
}) => <String, Object?>{
  'schemaVersion': 1,
  'sourceSha': 'same-sha',
  'profile': 'large',
  'fixture': <String, Object?>{'primaryObjects': 2500, 'relationTargets': 1000},
  'runtime': <String, Object?>{
    'dartVersion': 'test-dart',
    'operatingSystem': 'linux',
    'operatingSystemVersion': 'test-os',
  },
  'scenarios': <Map<String, Object?>>[
    <String, Object?>{
      'name': 'scenario-a',
      'unit': 'microseconds',
      'samples': <int>[1, 2, 3],
      'summary': <String, Object?>{
        'min': median,
        'median': median,
        'p95': p95,
        'max': p95,
      },
    },
  ],
};
