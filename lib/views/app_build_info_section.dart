import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/build_provenance.dart';
import '../ui/ui_tokens.dart';

class AppBuildInfoSection extends StatelessWidget {
  const AppBuildInfoSection({
    super.key,
    required this.provenance,
    this.copyText,
  });

  final BuildProvenance provenance;
  final Future<void> Function(String text)? copyText;

  Future<void> _copy(BuildContext context) async {
    final text = provenance.compactDiagnostic;
    final copier =
        copyText ?? (value) => Clipboard.setData(ClipboardData(text: value));
    await copier(text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('ビルド情報をコピーしました。')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'アプリ情報',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: UiTokens.space8),
        Text(
          'インストール中のアプリがどのソースから作られたか確認できます。',
          style: TextStyle(
            fontSize: UiTokens.textSm,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: UiTokens.space12),
        SelectableText(
          'Version ${provenance.displayVersion} (${provenance.displayBuildNumber})\n'
          'Channel ${provenance.displayReleaseChannel}\n'
          'Commit ${provenance.shortCommit}\n'
          'Source ${provenance.displaySourceState}',
          style: const TextStyle(fontSize: UiTokens.textSm),
        ),
        const SizedBox(height: UiTokens.space12),
        OutlinedButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_outlined, size: UiTokens.iconSmall),
          label: const Text('ビルド情報をコピー'),
        ),
      ],
    );
  }
}
