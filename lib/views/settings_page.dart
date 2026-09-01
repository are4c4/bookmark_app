import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../ui/ui_tokens.dart';
import 'auto_organize_settings_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.repository,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final BookmarkRepository repository;

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
                if (selection.isNotEmpty) onThemeModeChanged(selection.first);
              },
            ),
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
