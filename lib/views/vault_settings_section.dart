import 'package:flutter/material.dart';

import '../services/vault_directory_service.dart';
import '../ui/ui_tokens.dart';

class VaultSettingsSection extends StatelessWidget {
  const VaultSettingsSection({
    super.key,
    required this.directoryPath,
    this.revealDirectory,
  });

  final String directoryPath;
  final Future<void> Function(String path)? revealDirectory;

  static const _directoryService = VaultDirectoryService();

  String get _vaultName {
    final normalized = directoryPath.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    return segments.isEmpty ? directoryPath : segments.last;
  }

  Future<void> _reveal(BuildContext context) async {
    try {
      final reveal = revealDirectory ?? _directoryService.revealInFinder;
      await reveal(directoryPath);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'VaultをFinderで表示できませんでした。保存場所を確認してください。',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'データ保管庫 (Vault)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: UiTokens.space8),
        Text(
          'このVaultにデータベース、写真、添付ファイルを保存します。',
          style: TextStyle(
            fontSize: UiTokens.textSm,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: UiTokens.space16),
        Text(
          _vaultName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: UiTokens.space4),
        Tooltip(
          message: directoryPath,
          child: Text(
            directoryPath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: UiTokens.textSm,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: UiTokens.space12),
        OutlinedButton.icon(
          onPressed: () => _reveal(context),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Finderで表示'),
        ),
      ],
    );
  }
}
