import 'package:flutter/material.dart';

class NotionInlineField extends StatefulWidget {
  const NotionInlineField({
    super.key,
    required this.value,
    required this.onSaved,
    this.hintText = 'クリックして編集',
    this.style,
    this.maxLines = 1,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  });

  final String value;
  final Future<void> Function(String value) onSaved;
  final String hintText;
  final TextStyle? style;
  final int? maxLines;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<NotionInlineField> createState() => _NotionInlineFieldState();
}

class _NotionInlineFieldState extends State<NotionInlineField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant NotionInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus) _save();
  }

  Future<void> _save() async {
    if (_saving) return;
    final next = _controller.text.trim();
    if (next == widget.value.trim()) return;
    setState(() => _saving = true);
    try {
      await widget.onSaved(next);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: !_saving,
      maxLines: widget.maxLines,
      style: widget.style,
      textInputAction: widget.maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
      onSubmitted: widget.maxLines == 1 ? (_) => _save() : null,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .7)),
        contentPadding: widget.contentPadding,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
