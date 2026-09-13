import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/support_diagnostics.dart';
import '../ui/ui_tokens.dart';

class SupportDiagnosticsSection extends StatefulWidget {
  const SupportDiagnosticsSection({
    super.key,
    required this.diagnostics,
    this.copyText,
  });

  final SupportDiagnosticsService diagnostics;
  final Future<void> Function(String text)? copyText;

  @override
  State<SupportDiagnosticsSection> createState() =>
      _SupportDiagnosticsSectionState();
}

class _SupportDiagnosticsSectionState extends State<SupportDiagnosticsSection> {
  bool _busy = false;

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    widget.diagnostics.events.record(
      category: 'support.bundle',
      severity: DiagnosticSeverity.info,
      code: 'copy_requested',
    );
    try {
      final bundle = await widget.diagnostics.collect();
      final copier =
          widget.copyText ??
          (text) => Clipboard.setData(ClipboardData(text: text));
      await copier(bundle.prettyJson);
      widget.diagnostics.events.record(
        category: 'support.bundle',
        severity: DiagnosticSeverity.info,
        code: 'copy_completed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('診断情報をコピーしました。')));
    } catch (_) {
      widget.diagnostics.events.record(
        category: 'support.bundle',
        severity: DiagnosticSeverity.error,
        code: 'copy_failed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('診断情報を作成できませんでした。')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'サポート情報',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: UiTokens.space8),
        Text(
          '不具合報告に使える技術情報を、プライバシーに配慮したJSONとしてコピーします。',
          style: TextStyle(
            fontSize: UiTokens.textSm,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: UiTokens.space8),
        Text(
          'Objectのタイトル・Body・URL/ドメイン・ローカルパス・ファイル名/内容・秘密情報・Vault/DB本体は既定では含めません。',
          style: TextStyle(
            fontSize: UiTokens.textSm,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: UiTokens.space12),
        OutlinedButton.icon(
          key: const ValueKey('copy-support-diagnostics'),
          onPressed: _busy ? null : _copy,
          icon: _busy
              ? const SizedBox.square(
                  dimension: UiTokens.iconSmall,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.content_copy_outlined,
                  size: UiTokens.iconSmall,
                ),
          label: Text(_busy ? '診断情報を作成中…' : '診断情報をコピー'),
        ),
      ],
    );
  }
}
