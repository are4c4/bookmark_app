import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../services/vault_lifecycle_scope.dart';
import '../ui/ui_tokens.dart';
import 'auto_organize_settings_section.dart';
import 'database_backup_settings_section.dart';
import 'vault_settings_section.dart';
import 'vault_switch_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.repository,
    this.exportBackupFile,
    this.chooseBackupFile,
    this.restoreBackupFile,
    this.revealVaultDirectory,
    this.onCreateVault,
    this.onOpenVault,
    this.onSwitchVault,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final BookmarkRepository repository;
  final Future<String?> Function()? exportBackupFile;
  final Future<String?> Function()? chooseBackupFile;
  final Future<void> Function(String path)? restoreBackupFile;
  final Future<void> Function(String path)? revealVaultDirectory;
  final VoidCallback? onCreateVault;
  final VoidCallback? onOpenVault;
  final VoidCallback? onSwitchVault;

  Future<void> _runVaultAction(
    BuildContext context,
    Future<void> Function() action,
    String failureMessage,
  ) async {
    try {
      await action();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  Future<void> _switchVaultFromScope(
    BuildContext context,
    VaultLifecycleScope scope,
  ) async {
    final selected = await showVaultSwitchDialog(
      context,
      state: scope.profileState,
    );
    if (selected == null || !context.mounted) return;
    await _runVaultAction(
      context,
      () => scope.switchVault(selected),
      'Vaultを切り替えられませんでした。現在のVaultは変更されていません。',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vaultPath = repository.profileDirectoryPath?.trim();
    final vaultScope = VaultLifecycleScope.maybeOf(context);
    final VoidCallback? createVaultAction = onCreateVault ??
        (vaultScope == null
            ? null
            : () async {
                await _runVaultAction(
                  context,
                  vaultScope.createVault,
                  '新しいVaultを作成できませんでした。現在のVaultは変更されていません。',
                );
              });
    final VoidCallback? openVaultAction = onOpenVault ??
        (vaultScope == null
            ? null
            : () async {
                await _runVaultAction(
                  context,
                  vaultScope.openVault,
                  'Vaultを開けませんでした。現在のVaultは変更されていません。',
                );
              });
    final VoidCallback? switchVaultAction = onSwitchVault ??
        (vaultScope == null
            ? null
            : () async {
                await _switchVaultFromScope(context, vaultScope);
              });
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: UiTokens.appBarHeight,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_outlined, size: UiTokens.iconNormal),
            SizedBox(width: UiTokens.space6),
            Text('設定', style: TextStyle(fontSize: UiTokens.textLg)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(UiTokens.space24),
        children: [
          const Text(
            '外観',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: UiTokens.space8),
          Text(
            'アプリの配色を選択します。設定は再起動後も保持されます。',
            style: TextStyle(
              fontSize: UiTokens.textSm,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: UiTokens.space16),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined, size: 17),
                  label: Text('システム'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined, size: 17),
                  label: Text('ライト'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined, size: 17),
                  label: Text('ダーク'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  onThemeModeChanged(selection.first);
                }
              },
            ),
          ),
          if (vaultPath != null && vaultPath.isNotEmpty) ...[
            const SizedBox(height: UiTokens.space24),
            const Divider(),
            const SizedBox(height: UiTokens.space24),
            VaultSettingsSection(
              directoryPath: vaultPath,
              revealDirectory: revealVaultDirectory,
              onCreateVault: createVaultAction,
              onOpenVault: openVaultAction,
              onSwitchVault: switchVaultAction,
            ),
          ],
          const SizedBox(height: UiTokens.space24),
          const Divider(),
          const SizedBox(height: UiTokens.space24),
          DatabaseBackupSettingsSection(
            repository: repository,
            exportBackupFile: exportBackupFile,
            chooseBackupFile: chooseBackupFile,
            restoreBackupFile: restoreBackupFile,
          ),
          const SizedBox(height: UiTokens.space24),
          const Divider(),
          const SizedBox(height: UiTokens.space24),
          AutoOrganizeSettingsSection(repository: repository),
        ],
      ),
    );
  }
}
