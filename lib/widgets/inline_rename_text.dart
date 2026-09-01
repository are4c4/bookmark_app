import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InlineRenameText extends StatefulWidget {
  const InlineRenameText({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.fallback,
    this.style,
    this.maxLines = 1,
    this.tooltip = 'ダブルクリックで名前を変更',
  });

  final String value;
  final String? fallback;
  final TextStyle? style;
  final int maxLines;
  final String tooltip;
  final Future<void> Function(String value) onSubmitted;

  @override
  State<InlineRenameText> createState() => _InlineRenameTextState();
}

class _InlineRenameTextState extends State<InlineRenameText> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;
  bool _saving = false;

  String get _displayValue =>
      widget.value.trim().isEmpty ? (widget.fallback ?? '') : widget.value;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant InlineRenameText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (_saving) return;
    setState(() {
      _editing = true;
      _controller.text = widget.value;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _cancel() {
    if (_saving) return;
    setState(() {
      _editing = false;
      _controller.text = widget.value;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final value = _controller.text.trim();
    if (value.isEmpty || value == widget.value.trim()) {
      _cancel();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmitted(value);
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _startEditing,
          child: Text(
            _displayValue,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          ),
        ),
      );
    }

    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          _cancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        key: const ValueKey('inline-rename-field'),
        controller: _controller,
        focusNode: _focusNode,
        enabled: !_saving,
        style: widget.style,
        maxLines: widget.maxLines,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onTapOutside: (_) => _submit(),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
