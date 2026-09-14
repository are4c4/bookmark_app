import 'dart:convert';
import 'dart:io';

class PerformanceVarianceScenario {
  const PerformanceVarianceScenario({
    required this.name,
    required this.mediansMicros,
    required this.p95Micros,
  });

  final String name;
  final List<num> mediansMicros;
  final List<num> p95Micros;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'median': _spreadJson(mediansMicros),
    'p95': _spreadJson(p95Micros),
  };

  String toMarkdownRow() {
    final medianSpread = _relativeSpreadPercent(mediansMicros);
    final p95Spread = _relativeSpreadPercent(p95Micros);
    return '| $name | ${medianSpread.toStringAsFixed(1)}% | '
        '${p95Spread.toStringAsFixed(1)}% |';
  }
}

class PerformanceVarianceReport {
  const PerformanceVarianceReport({
    required this.sourceSha,
    required this.profile,
    required this.runtime,
    required this.fixture,
    required this.runCount,
    required this.scenarios,
  });

  final String sourceSha;
  final String profile;
  final Map<String, Object?> runtime;
  final Map<String, Object?> fixture;
  final int runCount;
  final List<PerformanceVarianceScenario> scenarios;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'sourceSha': sourceSha,
    'profile': profile,
    'runtime': runtime,
    'fixture': fixture,
    'runCount': runCount,
    'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
  };

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Performance benchmark variance')
      ..writeln()
      ..writeln('- Source SHA: `$sourceSha`')
      ..writeln('- Profile: `$profile`')
      ..writeln('- Independent runs: $runCount')
      ..writeln()
      ..writeln('| Scenario | Median spread | p95 spread |')
      ..writeln('| --- | ---: | ---: |');
    for (final scenario in scenarios) {
      buffer.writeln(scenario.toMarkdownRow());
    }
    buffer
      ..writeln()
      ..writeln(
        '> Advisory only: relative spread is max-minus-min divided by the '
        'cross-run median. It is evidence for setting future budgets, not a '
        'blocking budget itself.',
      );
    return buffer.toString();
  }
}

PerformanceVarianceReport aggregatePerformanceBenchmarkReports(
  List<Map<String, Object?>> reports,
) {
  if (reports.length < 2) {
    throw ArgumentError.value(
      reports.length,
      'reports',
      'At least two benchmark reports are required.',
    );
  }

  final first = reports.first;
  _requireSchema(first);
  final sourceSha = _requireString(first, 'sourceSha');
  final profile = _requireString(first, 'profile');
  final runtime = _requireMap(first, 'runtime');
  final fixture = _requireMap(first, 'fixture');
  final firstScenarios = _requireScenarios(first);
  final scenarioNames = firstScenarios
      .map((scenario) => _requireString(scenario, 'name'))
      .toList(growable: false);

  final medianSamples = <String, List<num>>{
    for (final name in scenarioNames) name: <num>[],
  };
  final p95Samples = <String, List<num>>{
    for (final name in scenarioNames) name: <num>[],
  };

  for (final report in reports) {
    _requireSchema(report);
    if (_requireString(report, 'sourceSha') != sourceSha ||
        _requireString(report, 'profile') != profile ||
        !_deepEqual(_requireMap(report, 'runtime'), runtime) ||
        !_deepEqual(_requireMap(report, 'fixture'), fixture)) {
      throw const FormatException(
        'Benchmark reports must share source SHA, profile, runtime, and fixture.',
      );
    }

    final scenarios = _requireScenarios(report);
    final names = scenarios
        .map((scenario) => _requireString(scenario, 'name'))
        .toList(growable: false);
    if (!_deepEqual(names, scenarioNames)) {
      throw const FormatException(
        'Benchmark reports must share the same ordered scenario set.',
      );
    }

    for (final scenario in scenarios) {
      final name = _requireString(scenario, 'name');
      final summary = _requireMap(scenario, 'summary');
      medianSamples[name]!.add(_requireNum(summary, 'median'));
      p95Samples[name]!.add(_requireNum(summary, 'p95'));
    }
  }

  return PerformanceVarianceReport(
    sourceSha: sourceSha,
    profile: profile,
    runtime: Map.unmodifiable(runtime),
    fixture: Map.unmodifiable(fixture),
    runCount: reports.length,
    scenarios: List.unmodifiable(
      scenarioNames.map(
        (name) => PerformanceVarianceScenario(
          name: name,
          mediansMicros: List.unmodifiable(medianSamples[name]!),
          p95Micros: List.unmodifiable(p95Samples[name]!),
        ),
      ),
    ),
  );
}

Future<void> main(List<String> arguments) async {
  final values = <String, List<String>>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--') || !argument.contains('=')) {
      throw FormatException('Expected --name=value, got "$argument".');
    }
    final separator = argument.indexOf('=');
    values.putIfAbsent(argument.substring(2, separator), () => <String>[]).add(
      argument.substring(separator + 1),
    );
  }

  final inputPaths = values['input'] ?? const <String>[];
  if (inputPaths.length < 2) {
    throw const FormatException('Provide at least two --input report paths.');
  }
  final reports = <Map<String, Object?>>[];
  for (final path in inputPaths) {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Benchmark report "$path" is not a JSON object.');
    }
    reports.add(decoded.cast<String, Object?>());
  }

  final report = aggregatePerformanceBenchmarkReports(reports);
  final jsonText = const JsonEncoder.withIndent('  ').convert(report.toJson());
  final markdown = report.toMarkdown();
  stdout.writeln(markdown);

  final jsonPath = values['json']?.singleOrNull;
  final markdownPath = values['markdown']?.singleOrNull;
  if (jsonPath != null) await _writeFile(jsonPath, '$jsonText\n');
  if (markdownPath != null) await _writeFile(markdownPath, markdown);
}

Map<String, Object?> _spreadJson(List<num> values) {
  final sorted = [...values]..sort((left, right) => left.compareTo(right));
  return <String, Object?>{
    'min': sorted.first,
    'median': _median(sorted),
    'max': sorted.last,
    'relativeSpreadPercent': _relativeSpreadPercent(sorted),
  };
}

double _relativeSpreadPercent(List<num> values) {
  final sorted = [...values]..sort((left, right) => left.compareTo(right));
  final median = _median(sorted);
  if (median == 0) return sorted.last == sorted.first ? 0 : double.infinity;
  return ((sorted.last - sorted.first) / median) * 100;
}

num _median(List<num> sorted) {
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

void _requireSchema(Map<String, Object?> report) {
  if (report['schemaVersion'] != 1) {
    throw const FormatException('Unsupported benchmark report schemaVersion.');
  }
}

String _requireString(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! String || result.isEmpty) {
    throw FormatException('Expected non-empty string "$key".');
  }
  return result;
}

num _requireNum(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! num || !result.isFinite || result < 0) {
    throw FormatException('Expected non-negative finite number "$key".');
  }
  return result;
}

Map<String, Object?> _requireMap(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! Map) {
    throw FormatException('Expected object "$key".');
  }
  return result.cast<String, Object?>();
}

List<Map<String, Object?>> _requireScenarios(Map<String, Object?> report) {
  final raw = report['scenarios'];
  if (raw is! List || raw.isEmpty) {
    throw const FormatException('Expected non-empty scenarios list.');
  }
  return raw.map((value) {
    if (value is! Map) {
      throw const FormatException('Expected scenario object.');
    }
    return value.cast<String, Object?>();
  }).toList(growable: false);
}

bool _deepEqual(Object? left, Object? right) =>
    jsonEncode(left) == jsonEncode(right);

Future<void> _writeFile(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}
