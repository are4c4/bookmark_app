import 'dart:convert';

import 'package:bookmark_app/services/build_provenance.dart';
import 'package:bookmark_app/services/support_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

class _Provider implements SupportDiagnosticProvider {
  _Provider(this.id, this.fields);

  @override
  final String id;
  final List<DiagnosticField> fields;

  @override
  Future<List<DiagnosticField>> collect() async => fields;
}

class _FailingProvider implements SupportDiagnosticProvider {
  @override
  String get id => 'search_health';

  @override
  Future<List<DiagnosticField>> collect() async {
    throw StateError('raw provider failure that must never be exported');
  }
}

const _provenance = BuildProvenance(
  version: '0.1.0',
  buildNumber: '7',
  commitSha: '0123456789abcdef0123456789abcdef01234567',
  sourceState: 'clean',
  releaseChannel: 'stable',
);

const _runtime = SupportDiagnosticsRuntime(
  operatingSystem: 'macos',
  operatingSystemVersion: 'Version 26.0',
  dartVersion: '3.10.0 stable',
);

DateTime _fixedClock() => DateTime.utc(2026, 9, 13, 8, 0);

void main() {
  test(
    'default support bundle contains technical provenance without user content',
    () async {
      final service = SupportDiagnosticsService(
        buildProvenance: _provenance,
        databaseSchemaVersion: 16,
        vaultConfigured: true,
        runtime: _runtime,
        events: DiagnosticEventBuffer(clock: _fixedClock),
        clock: _fixedClock,
      );

      final bundle = await service.collect();
      final decoded = jsonDecode(bundle.prettyJson) as Map<String, dynamic>;

      expect(decoded['format'], 'bookmark_app_support_diagnostics');
      expect(decoded['formatVersion'], 1);
      expect(decoded['build']['version']['value'], '0.1.0');
      expect(decoded['build']['buildNumber']['value'], '7');
      expect(
        decoded['build']['commitSha']['value'],
        '0123456789abcdef0123456789abcdef01234567',
      );
      expect(decoded['build']['releaseChannel']['value'], 'stable');
      expect(decoded['runtime']['operatingSystem']['value'], 'macos');
      expect(decoded['database']['schemaVersion']['value'], 16);
      expect(decoded['vault']['configured']['value'], isTrue);
      expect(decoded['build']['version']['privacy'], 'technical');
      expect(
        decoded['build']['version']['reason'],
        'identify_semantic_version',
      );

      expect(bundle.prettyJson, isNot(contains('private object title')));
      expect(bundle.prettyJson, isNot(contains('private body text')));
      expect(bundle.prettyJson, isNot(contains('https://private.example')));
      expect(bundle.prettyJson, isNot(contains('/Users/private/Vault')));
      expect(bundle.prettyJson, contains('absolute_local_path'));
      expect(bundle.prettyJson, contains('database_or_vault_file'));
    },
  );

  test(
    'unsafe provider field fails closed without hiding core diagnostics',
    () async {
      final events = DiagnosticEventBuffer(clock: _fixedClock);
      final service = SupportDiagnosticsService(
        buildProvenance: _provenance,
        databaseSchemaVersion: 16,
        vaultConfigured: true,
        runtime: _runtime,
        events: events,
        clock: _fixedClock,
        providers: [
          _Provider('unsafe_provider', const [
            DiagnosticField(
              key: 'vault_path',
              value: '/Users/private/Vault',
              privacyClass: DiagnosticPrivacyClass.localPath,
              reasonCode: 'unsafe_test_field',
            ),
          ]),
        ],
      );

      final decoded = jsonDecode(
        (await service.collect()).prettyJson,
      ) as Map<String, dynamic>;

      expect(decoded['database']['schemaVersion']['value'], 16);
      expect(decoded['providers']['unsafe_provider']['status'], 'unavailable');
      expect(
        decoded['providers']['unsafe_provider']['code'],
        'privacy_rejected',
      );
      expect(jsonEncode(decoded), isNot(contains('/Users/private/Vault')));
      expect(events.snapshot().single.code, 'privacy_rejected');
    },
  );

  test(
    'one broken provider stays isolated and does not export exception text',
    () async {
      final service = SupportDiagnosticsService(
        buildProvenance: _provenance,
        databaseSchemaVersion: 16,
        vaultConfigured: false,
        runtime: _runtime,
        events: DiagnosticEventBuffer(clock: _fixedClock),
        clock: _fixedClock,
        providers: [
          _FailingProvider(),
          _Provider('object_health', const [
            DiagnosticField(
              key: 'available',
              value: true,
              privacyClass: DiagnosticPrivacyClass.technical,
              reasonCode: 'report_provider_availability',
            ),
          ]),
        ],
      );

      final bundle = await service.collect();
      final decoded = jsonDecode(bundle.prettyJson) as Map<String, dynamic>;

      expect(decoded['providers']['object_health']['status'], 'ok');
      expect(
        decoded['providers']['object_health']['fields']['available']['value'],
        isTrue,
      );
      expect(decoded['providers']['search_health']['status'], 'unavailable');
      expect(decoded['providers']['search_health']['code'], 'provider_error');
      expect(bundle.prettyJson, isNot(contains('raw provider failure')));
    },
  );

  test(
    'provider technical strings must also be fixed diagnostic tokens',
    () async {
      final service = SupportDiagnosticsService(
        buildProvenance: _provenance,
        databaseSchemaVersion: 16,
        vaultConfigured: true,
        runtime: _runtime,
        events: DiagnosticEventBuffer(clock: _fixedClock),
        clock: _fixedClock,
        providers: [
          _Provider('misclassified_provider', const [
            DiagnosticField(
              key: 'state',
              value: 'Private object title accidentally misclassified',
              privacyClass: DiagnosticPrivacyClass.technical,
              reasonCode: 'report_health_state',
            ),
          ]),
        ],
      );

      final bundle = await service.collect();
      final decoded = jsonDecode(bundle.prettyJson) as Map<String, dynamic>;

      expect(
        decoded['providers']['misclassified_provider']['status'],
        'unavailable',
      );
      expect(
        decoded['providers']['misclassified_provider']['code'],
        'provider_error',
      );
      expect(bundle.prettyJson, isNot(contains('Private object title')));
    },
  );

  test('event retention is bounded and stores codes instead of messages', () {
    var tick = 0;
    final events = DiagnosticEventBuffer(
      maxEntries: 2,
      clock: () => DateTime.utc(2026, 9, 13, 8, tick++),
    );

    events.record(
      category: 'vault.lifecycle',
      severity: DiagnosticSeverity.info,
      code: 'open_started',
    );
    events.record(
      category: 'vault.lifecycle',
      severity: DiagnosticSeverity.warning,
      code: 'open_retry',
    );
    events.record(
      category: 'vault.lifecycle',
      severity: DiagnosticSeverity.error,
      code: 'open_failed',
    );

    final snapshot = events.snapshot();
    expect(snapshot, hasLength(2));
    expect(snapshot.map((event) => event.code), ['open_retry', 'open_failed']);
    expect(
      () => events.record(
        category: 'vault lifecycle private title',
        severity: DiagnosticSeverity.error,
        code: 'bad',
      ),
      throwsFormatException,
    );
  });

  test(
    'snapshot output is deterministic with fixed inputs and provider ordering',
    () async {
      SupportDiagnosticsService service(
        Iterable<SupportDiagnosticProvider> providers,
      ) => SupportDiagnosticsService(
        buildProvenance: _provenance,
        databaseSchemaVersion: 16,
        vaultConfigured: true,
        runtime: _runtime,
        events: DiagnosticEventBuffer(clock: _fixedClock),
        clock: _fixedClock,
        providers: providers,
      );

      final a = _Provider('a_health', const [
        DiagnosticField(
          key: 'count',
          value: 3,
          privacyClass: DiagnosticPrivacyClass.aggregate,
          reasonCode: 'report_aggregate_count',
        ),
      ]);
      final z = _Provider('z_health', const [
        DiagnosticField(
          key: 'ready',
          value: true,
          privacyClass: DiagnosticPrivacyClass.technical,
          reasonCode: 'report_health_state',
        ),
      ]);

      final first = (await service([z, a]).collect()).prettyJson;
      final second = (await service([a, z]).collect()).prettyJson;

      expect(first, second);
      expect(first.indexOf('a_health'), lessThan(first.indexOf('z_health')));
    },
  );
}
