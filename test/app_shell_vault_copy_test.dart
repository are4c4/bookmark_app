import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app shell presents Profile compatibility flows as Vault', () async {
    final source = await File('lib/views/app_shell.dart').readAsString();

    for (final legacyCopy in const [
      "'Profileを追加'",
      "'Profileバックアップを保存しました: \$path'",
      "'復元するProfile名'",
      "'復元したProfile'",
      "'Profileを切り替え'",
      "'＋ Profileを追加'",
      "'Profileを管理'",
      "'Profile管理'",
      "'Profileを完全バックアップ'",
      "'バックアップからProfileを復元'",
    ]) {
      expect(source, isNot(contains(legacyCopy)), reason: legacyCopy);
    }

    for (final vaultCopy in const [
      "'Vaultを追加'",
      "'Vaultバックアップを保存しました: \$path'",
      "'復元するVault名'",
      "'復元したVault'",
      "'Vaultを切り替え'",
      "'＋ Vaultを追加'",
      "'Vaultを管理'",
      "'Vault管理'",
      "'Vaultを完全バックアップ'",
      "'バックアップからVaultを復元'",
    ]) {
      expect(source, contains(vaultCopy), reason: vaultCopy);
    }

    // Internal compatibility identifiers remain intentionally Profile-based.
    expect(source, contains("value: 'profile_export'"));
    expect(source, contains("value: 'profile_import'"));
    expect(source, contains('ProfileManagementPage('));
  });
}
