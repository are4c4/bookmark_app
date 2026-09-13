import 'dart:convert';
import 'dart:io';

import 'build_provenance.dart';

enum DiagnosticPrivacyClass {
  technical,
  aggregate,
  sanitizedCode,
  userContent,
  localPath,
  url,
  secret;

  bool get allowedByDefault => switch (this) {
        technical || aggregate || sanitizedCode => true,
        userContent || localPath || url || secret => false,
      };

  String get wireName => switch (this) {
        technical => 'technical',
        aggregate => 'aggregate',
        sanitizedCode => 'sanitized_code',
        userContent => 'user_content',
        localPath => 'local_path',
        url => 'url',
        secret => 'secret',
      };
}

enum DiagnosticSeverity {
  info,
  warning,
  error;

  String get wireName => name;
}

class DiagnosticField {
  const DiagnosticField({
    required this.key,
    required this.value,
    required this.privacyClass,
    required this.reason,
  });

  final String key;
  final Object? value;
  final DiagnosticPrivacyClass privacyClass;
  final String reason;
}

abstract interface class SupportDiagnosticProvider {
  String get id;

  Future<List<DiagnosticField>> collect();
}

class DiagnosticEvent {
  const DiagnosticEvent({
    required this.timestamp,
    required this.category,
    required this.severity,
    required this.code,
  });

  final DateTime timestamp;
  final String category;
  final DiagnosticSeverity severity;
  final String code;
}

class DiagnosticEventBuffer {
  DiagnosticEventBuffer({
    this.maxEntries = 50,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (maxEntries <= 0) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'must be positive');
    }
  }

  static final shared = DiagnosticEventBuffer();

  final int maxEntries;
  final DateTime Function() _clock;
  final List<DiagnosticEvent> _events = <DiagnosticEvent>[];

  void record({
    required String category,
    required DiagnosticSeverity severity,
    required String code,
  }) {
    _validateDiagnosticToken(category, 'category');
    _validateDiagnosticToken(code, 'code');
    _events.add(
      DiagnosticEvent(
        timestamp: _clock().toUtc(),
        category: category,
        severity: severity,
        code: code,
      ),
    );
    final overflow = _events.length - maxEntries;
    if (overflow > 0) {
      _events.removeRange(0, overflow);
    }
  }

  List<DiagnosticEvent> snapshot() => List<DiagnosticEvent>.unmodifiable(_events);

  void clear() => _events.clear();
}

class SupportDiagnosticsRuntime {
  const SupportDiagnosticsRuntime({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.dartVersion,
  });

  factory SupportDiagnosticsRuntime.current() => SupportDiagnosticsRuntime(
        operatingSystem: Platform.operatingSystem,
        operatingSystemVersion: Platform.operatingSystemVersion,
        dartVersion: Platform.version,
      );

  final String operatingSystem;
  final String operatingSystemVersion;
  final String dartVersion;
}

class SupportDiagnosticsBundle {
  const SupportDiagnosticsBundle(this.payload);

  final Map<String, Object?> payload;

  String get prettyJson => '${const JsonEncoder.withIndent('  ').convert(payload)}\n';
}

class SupportDiagnosticsService {
  SupportDiagnosticsService({
    required this.buildProvenance,
    required this.databaseSchemaVersion,
    required this.vaultConfigured,
    SupportDiagnosticsRuntime? runtime,
    DiagnosticEventBuffer? events,
    Iterable<SupportDiagnosticProvider> providers = const <SupportDiagnosticProvider>[],
    DateTime Function()? clock,
  })  : runtime = runtime ?? SupportDiagnosticsRuntime.current(),
        events = events ?? DiagnosticEventBuffer.shared,
        providers = List<SupportDiagnosticProvider>.unmodifiable(providers),
        _clock = clock ?? DateTime.now;

  final BuildProvenance buildProvenance;
  final int databaseSchemaVersion;
  final bool vaultConfigured;
  final SupportDiagnosticsRuntime runtime;
  final DiagnosticEventBuffer events;
  final List<SupportDiagnosticProvider> providers;
  final DateTime Function() _clock;

  Future<SupportDiagnosticsBundle> collect() async {
    final providerPayload = <String, Object?>{};
    final orderedProviders = [...providers]
      ..sort((left, right) => left.id.compareTo(right.id));

    for (final provider in orderedProviders) {
      final providerId = provider.id;
      try {
        _validateDiagnosticToken(providerId, 'provider id');
        final fields = await provider.collect();
        final orderedFields = [...fields]
          ..sort((left, right) => left.key.compareTo(right.key));
        final renderedFields = <String, Object?>{};
        final seenKeys = <String>{};
        for (final field in orderedFields) {
          _validateDiagnosticToken(field.key, 'field key');
          if (!seenKeys.add(field.key)) {
            throw const FormatException('duplicate diagnostic field key');
          }
          if (!field.privacyClass.allowedByDefault) {
            throw const _UnsafeDiagnosticField();
          }
          renderedFields[field.key] = _renderField(field);
        }
        providerPayload[providerId] = <String, Object?>{
          'status': 'ok',
          'fields': renderedFields,
        };
      } on _UnsafeDiagnosticField {
        events.record(
          category: 'support.provider',
          severity: DiagnosticSeverity.warning,
          code: 'privacy_rejected',
        );
        providerPayload[providerId] = const <String, Object?>{
          'status': 'unavailable',
          'code': 'privacy_rejected',
        };
      } catch (_) {
        events.record(
          category: 'support.provider',
          severity: DiagnosticSeverity.warning,
          code: 'provider_error',
        );
        providerPayload[_safeProviderId(providerId)] = const <String, Object?>{
          'status': 'unavailable',
          'code': 'provider_error',
        };
      }
    }

    final eventPayload = events.snapshot().map(_renderEvent).toList(growable: false);
    return SupportDiagnosticsBundle(<String, Object?>{
      'format': 'bookmark_app_support_diagnostics',
      'formatVersion': 1,
      'generatedAt': _renderField(
        DiagnosticField(
          key: 'generatedAt',
          value: _clock().toUtc().toIso8601String(),
          privacyClass: DiagnosticPrivacyClass.technical,
          reason: 'Compare when two diagnostic snapshots were collected.',
        ),
      ),
      'privacy': const <String, Object?>{
        'defaultScope': 'technical_metadata_only',
        'excludedByDefault': <String>[
          'object_title',
          'body_text',
          'captured_url_or_domain',
          'absolute_local_path',
          'user_file_name_or_content',
          'secret_token_cookie',
          'database_or_vault_file',
        ],
      },
      'build': <String, Object?>{
        'version': _renderField(
          DiagnosticField(
            key: 'version',
            value: buildProvenance.displayVersion,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Identify the installed semantic application version.',
          ),
        ),
        'buildNumber': _renderField(
          DiagnosticField(
            key: 'buildNumber',
            value: buildProvenance.displayBuildNumber,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Identify the exact packaged build number.',
          ),
        ),
        'commitSha': _renderField(
          DiagnosticField(
            key: 'commitSha',
            value: _normalizedOrUnknown(buildProvenance.commitSha),
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Map the installed build to repository source provenance.',
          ),
        ),
        'sourceState': _renderField(
          DiagnosticField(
            key: 'sourceState',
            value: buildProvenance.displaySourceState,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Distinguish clean packaged source from development state.',
          ),
        ),
        'releaseChannel': _renderField(
          DiagnosticField(
            key: 'releaseChannel',
            value: buildProvenance.displayReleaseChannel,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Distinguish development, release-candidate and stable builds.',
          ),
        ),
      },
      'runtime': <String, Object?>{
        'operatingSystem': _renderField(
          DiagnosticField(
            key: 'operatingSystem',
            value: runtime.operatingSystem,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Identify the runtime platform family.',
          ),
        ),
        'operatingSystemVersion': _renderField(
          DiagnosticField(
            key: 'operatingSystemVersion',
            value: runtime.operatingSystemVersion,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Identify platform/runtime compatibility conditions.',
          ),
        ),
        'dartVersion': _renderField(
          DiagnosticField(
            key: 'dartVersion',
            value: runtime.dartVersion,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Identify the Dart runtime/toolchain embedded in the build.',
          ),
        ),
      },
      'database': <String, Object?>{
        'schemaVersion': _renderField(
          DiagnosticField(
            key: 'schemaVersion',
            value: databaseSchemaVersion,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Identify the application schema contract expected by this build.',
          ),
        ),
      },
      'vault': <String, Object?>{
        'configured': _renderField(
          DiagnosticField(
            key: 'configured',
            value: vaultConfigured,
            privacyClass: DiagnosticPrivacyClass.technical,
            reason: 'Report whether a Vault is configured without exposing its path or name.',
          ),
        ),
      },
      'providers': providerPayload,
      'events': eventPayload,
    });
  }
}

Map<String, Object?> _renderField(DiagnosticField field) => <String, Object?>{
      'value': field.value,
      'privacy': field.privacyClass.wireName,
      'reason': field.reason,
    };

Map<String, Object?> _renderEvent(DiagnosticEvent event) => <String, Object?>{
      'timestamp': _renderField(
        DiagnosticField(
          key: 'timestamp',
          value: event.timestamp.toUtc().toIso8601String(),
          privacyClass: DiagnosticPrivacyClass.technical,
          reason: 'Order recent diagnostic events within the current app session.',
        ),
      ),
      'category': _renderField(
        DiagnosticField(
          key: 'category',
          value: event.category,
          privacyClass: DiagnosticPrivacyClass.sanitizedCode,
          reason: 'Identify a fixed diagnostic subsystem category without user content.',
        ),
      ),
      'severity': _renderField(
        DiagnosticField(
          key: 'severity',
          value: event.severity.wireName,
          privacyClass: DiagnosticPrivacyClass.sanitizedCode,
          reason: 'Classify event severity without storing an error message.',
        ),
      ),
      'code': _renderField(
        DiagnosticField(
          key: 'code',
          value: event.code,
          privacyClass: DiagnosticPrivacyClass.sanitizedCode,
          reason: 'Expose a bounded fixed error/event code instead of raw exception text.',
        ),
      ),
    };

String _safeProviderId(String value) {
  try {
    _validateDiagnosticToken(value, 'provider id');
    return value;
  } catch (_) {
    return 'invalid_provider';
  }
}

void _validateDiagnosticToken(String value, String label) {
  if (!RegExp(r'^[a-z0-9][a-z0-9_.-]{0,63}$').hasMatch(value)) {
    throw FormatException('$label must be a fixed lowercase diagnostic token');
  }
}

String _normalizedOrUnknown(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? 'unknown' : normalized;
}

class _UnsafeDiagnosticField implements Exception {
  const _UnsafeDiagnosticField();
}
