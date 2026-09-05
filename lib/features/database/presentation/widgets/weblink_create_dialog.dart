import 'package:flutter/material.dart';

class WeblinkCreateInput {
  const WeblinkCreateInput({required this.url, this.title});

  final String url;
  final String? title;
}

Future<WeblinkCreateInput?> showWeblinkCreateDialog(BuildContext context) {
  return showDialog<WeblinkCreateInput>(
    context: context,
    builder: (_) => const _WeblinkCreateDialog(),
  );
}

class _WeblinkCreateDialog extends StatefulWidget {
  const _WeblinkCreateDialog();

  @override
  State<_WeblinkCreateDialog> createState() => _WeblinkCreateDialogState();
}

class _WeblinkCreateDialogState extends State<_WeblinkCreateDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _urlController.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    final title = _titleController.text.trim();
    Navigator.of(context).pop(
      WeblinkCreateInput(
        url: _urlController.text.trim(),
        title: title.isEmpty ? null : title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Weblinkを追加'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('weblink-create-url'),
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('weblink-create-title'),
              controller: _titleController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'タイトル（任意）',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const ValueKey('weblink-create-submit'),
          onPressed: _canSubmit ? _submit : null,
          child: const Text('追加'),
        ),
      ],
    );
  }
}
