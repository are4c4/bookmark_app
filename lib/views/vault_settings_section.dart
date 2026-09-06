import 'package:flutter/material.dart';

import '../services/vault_directory_service.dart';
import '../ui/ui_tokens.dart';

class VaultSettingsSection extends StatelessWidget {
  const VaultSettingsSection({
    super.key,
    required this.directoryPath,
    this.revealDirectory,
    this.onCreateVault,
    this.onOpenVault,
    this.onSwitchVault,
  });

  final String directoryPath;
  final Future<void> Function(String path)? revealDirectory;
  final VoidCallback? onCreateVault;
  final VoidCallback? onOpenVault;
  final VoidCallback? onSwitchVault;

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
    final hasManagementActions =
        onCreateVault != null || onOpenVault != null || onSwitchVault != null;
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
        Wrap(
          spacing: UiTokens.space8,
          runSpacing: UiTokens.space8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _reveal(context),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Finderで表示'),
            ),
            if (onCreateVault != null)
              FilledButton.tonalIcon(
                onPressed: onCreateVault,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('新しいVaultを作成'),
              ),
            if (onOpenVault != null)
              OutlinedButton.icon(
                onPressed: onOpenVault,
                icon: const Icon(Icons.folder_copy_outlined),
                label: const Text('既存のVaultを開く'),
              ),
            if (onSwitchVault != null)
              OutlinedButton.icon(
                onPressed: onSwitchVault,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Vaultを切り替える'),
              ),
          ],
        ),
        if (hasManagementActions) ...[
          const SizedBox(height: UiTokens.space8),
          Text(
            'Vaultの作成・オープン・切り替えでは、現在のデータベースを安全に閉じてから既存の起動経路で読み込み直します。',
            style: TextStyle(
              fontSize: UiTokens.textXs,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
