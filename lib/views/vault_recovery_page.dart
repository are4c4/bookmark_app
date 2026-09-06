import 'package:flutter/material.dart';

import '../services/vault_availability_service.dart';
import '../services/vault_registry_inspection_service.dart';
import '../ui/ui_tokens.dart';

class VaultRecoveryPage extends StatefulWidget {
  const VaultRecoveryPage({
    super.key,
    required this.locations,
    required this.onRelink,
    this.onUnregisterInactive,
    this.onRetry,
  });

  final List<VaultRegistryLocation> locations;
  final Future<void> Function(VaultRegistryLocation location) onRelink;
  final Future<void> Function(VaultRegistryLocation location)?
      onUnregisterInactive;
  final VoidCallback? onRetry;

  @override
  State<VaultRecoveryPage> createState() => _VaultRecoveryPageState();
}

class _VaultRecoveryPageState extends State<VaultRecoveryPage> {
  String? _busyProfileId;

  List<VaultRegistryLocation> get _unavailable => widget.locations
      .where((location) => !location.isAvailable)
      .toList(growable: false);

  Future<void> _run(
    VaultRegistryLocation location,
    Future<void> Function() operation,
  ) async {
    if (_busyProfileId != null) return;
    setState(() => _busyProfileId = location.profile.id);
    try {
      await operation();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vaultの復旧操作を完了できませんでした。保存場所または登録情報を確認してください。',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _confirmUnregister(VaultRegistryLocation location) async {
    final action = widget.onUnregisterInactive;
    if (action == null || location.isActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「${location.profile.name}」を登録から外しますか？'),
        content: const Text(
          'この操作はアプリのVault一覧から登録を外すだけです。元のフォルダやファイルは削除しません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('登録から外す'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(location, () => action(location));
    }
  }

  String _statusLabel(VaultAvailability availability) => switch (availability) {
        VaultAvailability.available => '利用可能',
        VaultAvailability.missingDirectory => 'フォルダが見つかりません',
        VaultAvailability.missingDatabase => 'database.sqlite が見つかりません',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unavailable = _unavailable;
    return Scaffold(
      appBar: AppBar(title: const Text('Vaultを復旧')),
      body: ListView(
        padding: const EdgeInsets.all(UiTokens.space24),
        children: [
          const Text(
            'Vaultの保存場所を確認してください',
            style: TextStyle(
              fontSize: UiTokens.textLg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: UiTokens.space8),
          Text(
            '登録済みのVaultにアクセスできません。元のVaultを自動生成したり空のデータベースで置き換えたりはしません。',
            style: TextStyle(
              fontSize: UiTokens.textSm,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: UiTokens.space24),
          if (unavailable.isEmpty) ...[
            const Text('現在、再接続が必要なVaultは見つかりませんでした。'),
            if (widget.onRetry != null) ...[
              const SizedBox(height: UiTokens.space16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('もう一度起動する'),
                ),
              ),
            ],
          ] else
            ...unavailable.map((location) {
              final busy = _busyProfileId == location.profile.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: UiTokens.space12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(UiTokens.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                location.profile.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (location.isActive)
                              const Chip(label: Text('現在のVault')),
                          ],
                        ),
                        const SizedBox(height: UiTokens.space6),
                        Text(
                          _statusLabel(location.availability),
                          style: TextStyle(
                            fontSize: UiTokens.textSm,
                            color: scheme.error,
                          ),
                        ),
                        const SizedBox(height: UiTokens.space6),
                        SelectableText(
                          location.profile.directoryPath,
                          style: TextStyle(
                            fontSize: UiTokens.textXs,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: UiTokens.space12),
                        Wrap(
                          spacing: UiTokens.space8,
                          runSpacing: UiTokens.space8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: busy || _busyProfileId != null
                                  ? null
                                  : () => _run(
                                        location,
                                        () => widget.onRelink(location),
                                      ),
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.folder_open_outlined),
                              label: const Text('場所を指定し直す'),
                            ),
                            if (!location.isActive &&
                                widget.onUnregisterInactive != null)
                              TextButton(
                                onPressed: busy || _busyProfileId != null
                                    ? null
                                    : () => _confirmUnregister(location),
                                child: const Text('登録から外す'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
