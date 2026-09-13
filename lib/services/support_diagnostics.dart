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
    required this.reasonCode,
  });

  final String key;
  final Object? value;
  final DiagnosticPrivacyClass privacyClass;
  final String reasonCode;
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
  DiagnosticEventBuffer({this.maxEntries = 50, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
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

  List<DiagnosticEvent> snapshot() =>
      List<DiagnosticEvent>.unmodifiable(_events);

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

  String get prettyJson =>
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n';
}

class SupportDiagnosticsService {
  SupportDiagnosticsService({
    required this.buildProvenance,
    required this.databaseSchemaVersion,
    required this.vaultConfigured,
    SupportDiagnosticsRuntime? runtime,
    DiagnosticEventBuffer? events,
    Iterable<SupportDiagnosticProvider> providers =
        const <SupportDiagnosticProvider>[],
    DateTime Function()? clock,
  }) : runtime = runtime ?? SupportDiagnosticsRuntime.current(),
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
    final seenProviderIds = <String>{};
    final orderedProviders = [...providers]
      ..sort((left, right) => left.id.compareTo(right.id));

    for (final provider in orderedProviders) {
      final providerId = provider.id;
      try {
        _validateDiagnosticToken(providerId, 'provider id');
        if (!seenProviderIds.add(providerId)) {
          throw const FormatException('duplicate diagnostic provider id');
        }
        final fields = await provider.collect();
        final orderedFields = [...fields]
          ..sort((left, right) => left.key.compareTo(right.key));
        final renderedFields = <String, Object?>{};
        final seenKeys = <String>{};
        for (final field in orderedFields) {
          _validateDiagnosticToken(field.key, 'field key');
          _validateDiagnosticToken(field.reasonCode, 'reason code');
          if (!seenKeys.add(field.key)) {
            throw const FormatException('duplicate diagnostic field key');
          }
          if (!field.privacyClass.allowedByDefault) {
            throw const _UnsafeDiagnosticField();
          }
          _validateProviderFieldValue(field);
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

    final eventPayload = events
        .snapshot()
        .map(_renderEvent)
        .toList(growable: false);
    return SupportDiagnosticsBundle(<String, Object?>{
      'format': 'bookmark_app_support_diagnostics',
      'formatVersion': 1,
      'generatedAt': _renderField(
        DiagnosticField(
          key: 'generated_at',
          value: _clock().toUtc().toIso8601String(),
          privacyClass: DiagnosticPrivacyClass.technical,
          reasonCode: 'compare_snapshot_time',
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
            reasonCode: 'identify_semantic_version',
          ),
        ),
        'buildNumber': _renderField(
          DiagnosticField(
            key: 'build_number',
            value: buildProvenance.displayBuildNumber,
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'identify_packaged_build',
          ),
        ),
        'commitSha': _renderField(
          DiagnosticField(
            key: 'commit_sha',
            value: _normalizedOrUnknown(buildProvenance.commitSha),
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'map_source_provenance',
          ),
        ),
        'sourceState': _renderField(
          DiagnosticField(
            key: 'source_state',
            value: buildProvenance.displaySourceState,
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'distinguish_source_state',
          ),
        ),
        'releaseChannel': _renderField(
          DiagnosticField(
            key: 'release_channel',
            value: buildProvenance.displayReleaseChannel,
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'identify_release_channel',
          ),
        ),
      },
      'runtime': <String, Object?>{
        'operatingSystem': _renderField(
          DiagnosticField(
            key: 'operating_system',
            value: runtime.operatingSystem,
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'identify_platform_family',
          ),
        ),
        'operatingSystemVersion': _renderField(
          DiagnosticField(
            key: 'operating_system_version',
            value: runtime.operatingSystemVersion,
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'identify_platform_version',
          ),
        ),
        'dartVersion': _renderField(
          DiagnosticField(
            key: 'dart_version',
            value: runtime.dartVersion,
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'identify_dart_runtime',
          ),
        ),
      },
      'database': <String, Object?>{
        'schemaVersion': _renderField(
          DiagnosticField(
            key: 'schema_version',
            value: databaseSchemaVersion,
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'identify_schema_contract',
          ),
        ),
      },
      'vault': <String, Object?>{
        'configured': _renderField(
          DiagnosticField(
            key: 'configured',
            value: vaultConfigured,
            privacyClass: DiagnosticPrivacyClass.technical,
            reasonCode: 'report_vault_presence_without_identity',
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
  'reason': field.reasonCode,
};

Map<String, Object?> _renderEvent(DiagnosticEvent event) => <String, Object?>{
  'timestamp': _renderField(
    DiagnosticField(
      key: 'timestamp',
      value: event.timestamp.toUtc().toIso8601String(),
      privacyClass: DiagnosticPrivacyClass.technical,
      reasonCode: 'order_session_events',
    ),
  ),
  'category': _renderField(
    DiagnosticField(
      key: 'category',
      value: event.category,
      privacyClass: DiagnosticPrivacyClass.sanitizedCode,
      reasonCode: 'identify_event_subsystem',
    ),
  ),
  'severity': _renderField(
    DiagnosticField(
      key: 'severity',
      value: event.severity.wireName,
      privacyClass: DiagnosticPrivacyClass.sanitizedCode,
      reasonCode: 'classify_event_severity',
    ),
  ),
  'code': _renderField(
    DiagnosticField(
      key: 'code',
      value: event.code,
      privacyClass: DiagnosticPrivacyClass.sanitizedCode,
      reasonCode: 'report_fixed_event_code',
    ),
  ),
};

void _validateProviderFieldValue(DiagnosticField field) {
  final value = field.value;
  switch (field.privacyClass) {
    case DiagnosticPrivacyClass.technical:
      if (value == null || value is bool || value is num) return;
      if (value is String) {
        _validateDiagnosticToken(value, 'technical provider value');
        return;
      }
      throw const FormatException('technical provider field must be a scalar');
    case DiagnosticPrivacyClass.aggregate:
      if (value == null || value is bool || value is num) return;
      throw const FormatException(
        'aggregate provider field must be numeric or boolean',
      );
    case DiagnosticPrivacyClass.sanitizedCode:
      if (value is! String) {
        throw const FormatException('sanitized provider field must be a token');
      }
      _validateDiagnosticToken(value, 'sanitized provider value');
      return;
    case DiagnosticPrivacyClass.userContent:
    case DiagnosticPrivacyClass.localPath:
    case DiagnosticPrivacyClass.url:
    case DiagnosticPrivacyClass.secret:
      throw const _UnsafeDiagnosticField();
  }
}

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
