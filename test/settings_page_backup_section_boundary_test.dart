import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SettingsPage delegates database backup workflow to focused section', () {
    final page = File('lib/views/settings_page.dart').readAsStringSync();
    final backup = File(
      'lib/views/database_backup_settings_section.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/database_backup_service.dart',
    ).readAsStringSync();

    expect(page, contains('DatabaseBackupSettingsSection('));
    expect(page, isNot(contains('DatabaseBackupService(')));
    expect(page, isNot(contains('workspaceStore.database')));
    expect(page, isNot(contains('_exportBackup(')));
    expect(page, isNot(contains('_restoreBackup(')));

    expect(backup, contains('DatabaseBackupService.fromRepository(repository)'));
    expect(backup, isNot(contains('workspaceStore.database')));
    expect(backup, contains('_exportBackup('));
    expect(backup, contains('_restoreBackup('));
    expect(backup, contains("name: 'bookmark_app.settings_backup'"));
    expect(
      backup,
      contains('バックアップを作成できませんでした。もう一度お試しください。'),
    );
    expect(
      backup,
      contains('バックアップを復元できませんでした。ファイルを確認して、もう一度お試しください。'),
    );

    expect(service, contains('factory DatabaseBackupService.fromRepository('));
    expect(service, contains('repository.workspaceStore.database'));
  });
}
