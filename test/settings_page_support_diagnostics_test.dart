import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/build_provenance.dart';
import 'package:bookmark_app/services/support_diagnostics.dart';
import 'package:bookmark_app/services/support_diagnostics_factory.dart';
import 'package:bookmark_app/views/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

DateTime _clock() => DateTime.utc(2026, 9, 13, 8);

Future<BookmarkRepository> _repository(
  AppDatabase database, {
  String? profileDirectoryPath,
}) async {
  final workspaceStore = WorkspaceStore(database);
  final workspaceId = await workspaceStore.initialize();
  final lifecycleStore = BookmarkLifecycleStore(database);
  await lifecycleStore.initialize();
  return BookmarkRepository(
    database,
    workspaceStore: workspaceStore,
    lifecycleStore: lifecycleStore,
    workspaceId: workspaceId,
    profileDirectoryPath: profileDirectoryPath,
  );
}

void main() {
  testWidgets('Settings copies privacy-safe support diagnostics without Vault path', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(
      database,
      profileDirectoryPath: '/Users/private/Vault',
    );
    final events = DiagnosticEventBuffer(clock: _clock);
    final diagnostics = createSupportDiagnosticsService(
      repository: repository,
      buildProvenance: _provenance,
      runtime: _runtime,
      events: events,
      clock: _clock,
    );
    String? copied;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          repository: repository,
          buildProvenance: _provenance,
          supportDiagnostics: diagnostics,
          copySupportDiagnostics: (text) async {
            copied = text;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('サポート情報'), 240);
    expect(find.text('サポート情報'), findsOneWidget);
    expect(find.textContaining('Objectのタイトル・Body・URL/ドメイン'), findsOneWidget);

    final button = find.byKey(const ValueKey('copy-support-diagnostics'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(copied, isNotNull);
    final decoded = jsonDecode(copied!) as Map<String, dynamic>;
    expect(decoded['build']['commitSha']['value'], _provenance.commitSha);
    expect(decoded['database']['schemaVersion']['value'], database.schemaVersion);
    expect(decoded['vault']['configured']['value'], isTrue);
    expect(decoded['events'], isNotEmpty);
    expect(decoded['events'].first['category']['value'], 'support.bundle');
    expect(decoded['events'].first['code']['value'], 'copy_requested');
    expect(copied, isNot(contains('/Users/private/Vault')));
    expect(find.text('診断情報をコピーしました。'), findsOneWidget);
  });

  testWidgets('support diagnostics copy failure reports fixed event without raw error', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = await _repository(database);
    final events = DiagnosticEventBuffer(clock: _clock);
    final diagnostics = createSupportDiagnosticsService(
      repository: repository,
      buildProvenance: _provenance,
      runtime: _runtime,
      events: events,
      clock: _clock,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          repository: repository,
          supportDiagnostics: diagnostics,
          copySupportDiagnostics: (_) async {
            throw StateError('clipboard raw private failure');
          },
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('サポート情報'), 240);
    final button = find.byKey(const ValueKey('copy-support-diagnostics'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('診断情報を作成できませんでした。'), findsOneWidget);
    expect(events.snapshot().map((event) => event.code), [
      'copy_requested',
      'copy_failed',
    ]);
  });
}
