import 'package:flutter/material.dart';

import '../domain/object_body.dart';
import '../domain/object_body_plain_text.dart';

/// Shared first-pass Body surface for Object detail containers.
///
/// The widget only edits paragraph-only documents. Documents containing richer
/// block types are rendered as protected content until a compatible block
/// editor is available, preventing accidental flattening or data loss.
class ObjectBodySection extends StatelessWidget {
  const ObjectBodySection({
    super.key,
    required this.document,
    required this.onSave,
    this.title = '本文',
  });

  static const _adapter = ObjectBodyPlainTextAdapter();

  final ObjectBodyDocument document;
  final Future<void> Function(String text) onSave;
  final String title;

  Future<void> _edit(BuildContext context) async {
    if (!_adapter.canEdit(document)) return;
    final controller = TextEditingController(text: _adapter.read(document));
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$titleを編集'),
        content: SizedBox(
          width: 560,
          child: TextField(
            key: const ValueKey('object-body-editor'),
            controller: controller,
            autofocus: true,
            minLines: 8,
            maxLines: 18,
            decoration: InputDecoration(
              hintText: '$titleを書き始める…',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final editable = _adapter.canEdit(document);
    final paragraphs = editable ? _adapter.read(document) : null;
    final hasText = paragraphs?.trim().isNotEmpty == true;

    return Column(
      key: const ValueKey('object-body-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (editable)
              TextButton.icon(
                key: const ValueKey('object-body-edit-button'),
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(hasText ? '編集' : '書き始める'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!editable)
          const Text(
            'この本文にはリッチブロックが含まれています。対応エディタが追加されるまで、内容を保護するため簡易編集は無効です。',
          )
        else if (!hasText)
          Text(
            '$titleはまだありません。',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          )
        else
          SelectableText(
            paragraphs!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
      ],
    );
  }
}
