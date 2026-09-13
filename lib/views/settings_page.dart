import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../services/build_provenance.dart';
import '../services/support_diagnostics.dart';
import '../services/support_diagnostics_factory.dart';
import '../services/vault_lifecycle_scope.dart';
import '../ui/ui_tokens.dart';
import 'app_build_info_section.dart';
import 'auto_organize_settings_section.dart';
import 'database_backup_settings_section.dart';
import 'support_diagnostics_section.dart';
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
    this.onMoveVault,
    this.buildProvenance = BuildProvenance.current,
    this.copyBuildInfo,
    this.supportDiagnostics,
    this.copySupportDiagnostics,
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
  final VoidCallback? onMoveVault;
  final BuildProvenance buildProvenance;
  final Future<void> Function(String text)? copyBuildInfo;
  final SupportDiagnosticsService? supportDiagnostics;
  final Future<void> Function(String text)? copySupportDiagnostics;

  Future<void> _runVaultAction(
    BuildContext context,
    Future<void> Function() action,
    String failureMessage, {
    required DiagnosticEventBuffer diagnosticEvents,
    required String failureCode,
  }) async {
    try {
      await action();
    } catch (_) {
      diagnosticEvents.record(
        category: 'vault.lifecycle',
        severity: DiagnosticSeverity.error,
        code: failureCode,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  Future<void> _switchVaultFromScope(
    BuildContext context,
    VaultLifecycleScope scope,
    DiagnosticEventBuffer diagnosticEvents,
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
      diagnosticEvents: diagnosticEvents,
      failureCode: 'switch_failed',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vaultPath = repository.profileDirectoryPath?.trim();
    final diagnostics = supportDiagnostics ??
        createSupportDiagnosticsService(
          repository: repository,
          buildProvenance: buildProvenance,
        );
    final vaultScope = VaultLifecycleScope.maybeOf(context);
    final VoidCallback? createVaultAction = onCreateVault ??
        (vaultScope == null
            ? null
            : () async {
                await _runVaultAction(
                  context,
                  vaultScope.createVault,
                  '新しいVaultを作成できませんでした。現在のVaultは変更されていません。',
                  diagnosticEvents: diagnostics.events,
                  failureCode: 'create_failed',
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
                  diagnosticEvents: diagnostics.events,
                  failureCode: 'open_failed',
                );
              });
    final VoidCallback? switchVaultAction = onSwitchVault ??
        (vaultScope == null
            ? null
            : () async {
                await _switchVaultFromScope(
                  context,
                  vaultScope,
                  diagnostics.events,
                );
              });
    final scopeMoveVault = vaultScope?.moveVault;
    final VoidCallback? moveVaultAction = onMoveVault ??
        (scopeMoveVault == null
            ? null
            : () async {
                await _runVaultAction(
                  context,
                  scopeMoveVault,
                  'Vaultを移動できませんでした。移動元のVaultは削除されていません。',
                  diagnosticEvents: diagnostics.events,
                  failureCode: 'move_failed',
                );
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
              onMoveVault: moveVaultAction,
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
          const SizedBox(height: UiTokens.space24),
          const Divider(),
          const SizedBox(height: UiTokens.space24),
          SupportDiagnosticsSection(
            diagnostics: diagnostics,
            copyText: copySupportDiagnostics,
          ),
          const SizedBox(height: UiTokens.space24),
          const Divider(),
          const SizedBox(height: UiTokens.space24),
          AppBuildInfoSection(
            provenance: buildProvenance,
            copyText: copyBuildInfo,
          ),
        ],
      ),
    );
  }
}
