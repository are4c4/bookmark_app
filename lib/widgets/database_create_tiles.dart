import 'package:flutter/material.dart';

/// Card displayed at the end of a gallery to create a new database item.
/// The text controller is owned by this widget, avoiding dialog/controller
/// lifetime races when the database updates while an item is being created.
class DatabaseCreateCard extends StatefulWidget {
  const DatabaseCreateCard({
    super.key,
    required this.label,
    required this.onCreate,
    this.icon = Icons.add,
    this.hintText,
    this.aspectRatio = 1.35,
  });

  final String label;
  final IconData icon;
  final String? hintText;
  final double aspectRatio;
  final Future<void> Function(String value) onCreate;

  @override
  State<DatabaseCreateCard> createState() => _DatabaseCreateCardState();
}

class _DatabaseCreateCardState extends State<DatabaseCreateCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onCreate(value);
      if (!mounted) return;
      _controller.clear();
      setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _start() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _editing ? null : _start,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(14),
            child: _editing
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !_saving,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: widget.hintText ?? '名前を入力して Enter',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    _controller.clear();
                                    setState(() => _editing = false);
                                  },
                            child: const Text('キャンセル'),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: _saving ? null : _submit,
                            child: _saving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 1.5),
                                  )
                                : const Text('追加'),
                          ),
                        ],
                      ),
                    ],
                  )
                : Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 20, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class DatabaseCreateRow extends StatefulWidget {
  const DatabaseCreateRow({
    super.key,
    required this.label,
    required this.onCreate,
    this.icon = Icons.add,
    this.hintText,
  });

  final String label;
  final IconData icon;
  final String? hintText;
  final Future<void> Function(String value) onCreate;

  @override
  State<DatabaseCreateRow> createState() => _DatabaseCreateRowState();
}

class _DatabaseCreateRowState extends State<DatabaseCreateRow> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onCreate(value);
      if (!mounted) return;
      _controller.clear();
      setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_editing) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _editing = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _focusNode.requestFocus();
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(widget.label, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: !_saving,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onTapOutside: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hintText ?? '名前を入力して Enter',
          prefixIcon: const Icon(Icons.add, size: 18),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Dialog-friendly quick create field whose controller is disposed together
/// with the TextField instead of by the caller after Navigator.pop().
class SafeQuickCreateField extends StatefulWidget {
  const SafeQuickCreateField({
    super.key,
    required this.onSubmitted,
    this.hintText = '名前を入力して Enter',
    this.autofocus = true,
    this.prefixIcon,
  });

  final Future<void> Function(String value) onSubmitted;
  final String hintText;
  final bool autofocus;
  final IconData? prefixIcon;

  @override
  State<SafeQuickCreateField> createState() => _SafeQuickCreateFieldState();
}

class _SafeQuickCreateFieldState extends State<SafeQuickCreateField> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    if (_saving) return;
    final value = raw.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmitted(value);
      if (mounted) _controller.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        enabled: !_saving,
        textInputAction: TextInputAction.done,
        onSubmitted: _submit,
        decoration: InputDecoration(
          prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 18),
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
          suffixIcon: _saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                )
              : null,
        ),
      );
}
