import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../services/database_backup_service.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_toast.dart';
import 'auto_organize_settings_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.repository,
    this.exportBackupFile,
    this.chooseBackupFile,
    this.restoreBackupFile,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final BookmarkRepository repository;
  final Future<String?> Function()? exportBackupFile;
  final Future<String?> Function()? chooseBackupFile;
  final Future<void> Function(String path)? restoreBackupFile;

  static void _debugBackupFailure(String message, StackTrace stackTrace) {
    assert(() {
      developer.log(
        message,
        name: 'bookmark_app.settings_backup',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final path = await (exportBackupFile?.call() ??
          DatabaseBackupService(
            repository.workspaceStore.database,
          ).exportToFile());
      if (!context.mounted || path == null) return;
      showAppToast(context, 'バックアップを書き出しました');
    } catch (_, stackTrace) {
      _debugBackupFailure('Database backup export failed.', stackTrace);
      if (context.mounted) {
        showAppToast(
          context,
          'バックアップを作成できませんでした。もう一度お試しください。',
          error: true,
        );
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final service = DatabaseBackupService(repository.workspaceStore.database);
    final path = await (chooseBackupFile?.call() ?? service.chooseBackupFile());
    if (path == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('バックアップから復元しますか？'),
        content: const Text(
          '現在のデータベース内容をバックアップの内容で置き換えます。念のため、先に現在のバックアップを書き出すことをおすすめします。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('復元'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (restoreBackupFile != null) {
        await restoreBackupFile!(path);
      } else {
        await service.restoreFromFile(path);
      }
      if (context.mounted) {
        showAppToast(context, 'バックアップを復元しました。画面を開き直すと反映されます。');
      }
    } catch (_, stackTrace) {
      _debugBackupFailure('Database backup restore failed.', stackTrace);
      if (context.mounted) {
        showAppToast(
          context,
          'バックアップを復元できませんでした。ファイルを確認して、もう一度お試しください。',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          const SizedBox(height: UiTokens.space24),
          const Divider(),
          const SizedBox(height: UiTokens.space24),
          const Text(
            'データ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: UiTokens.space8),
          Text(
            'ブックマーク、タグ、人物、写真の関連、コレクション、保存ビューなどをJSONとしてバックアップできます。',
            style: TextStyle(
              fontSize: UiTokens.textSm,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: UiTokens.space12),
          Wrap(
            spacing: UiTokens.space8,
            runSpacing: UiTokens.space8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _exportBackup(context),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('バックアップを書き出す'),
              ),
              OutlinedButton.icon(
                onPressed: () => _restoreBackup(context),
                icon: const Icon(Icons.restore_outlined, size: 18),
                label: const Text('バックアップから復元'),
              ),
            ],
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
