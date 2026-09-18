import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared single-line Object title editor for full-page and peek/detail hosts.
///
/// Persistence stays owned by the host through [onSaved]. This widget owns only
/// the interaction contract: Enter commits, Escape cancels, focus loss commits,
/// invalid empty input restores the last canonical title, and failed saves fail
/// closed by restoring that title.
class ObjectInlineTitleEditor extends StatefulWidget {
  const ObjectInlineTitleEditor({
    super.key,
    required this.value,
    required this.onSaved,
    this.onSaveError,
    this.hintText = '名前',
    this.style,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 4,
      vertical: 4,
    ),
  });

  final String value;
  final Future<void> Function(String value) onSaved;
  final ValueChanged<Object>? onSaveError;
  final String hintText;
  final TextStyle? style;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<ObjectInlineTitleEditor> createState() =>
      _ObjectInlineTitleEditorState();
}

class _ObjectInlineTitleEditorState extends State<ObjectInlineTitleEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late String _canonicalValue;
  bool _saving = false;
  bool _skipNextBlurCommit = false;

  @override
  void initState() {
    super.initState();
    _canonicalValue = widget.value;
    _controller = TextEditingController(text: _canonicalValue);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant ObjectInlineTitleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _canonicalValue = widget.value;
    if (!_focusNode.hasFocus && !_saving) {
      _replaceText(_canonicalValue);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    if (_skipNextBlurCommit) {
      _skipNextBlurCommit = false;
      return;
    }
    unawaited(_commit());
  }

  void _replaceText(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _cancel() {
    _replaceText(_canonicalValue);
    if (_focusNode.hasFocus) {
      _skipNextBlurCommit = true;
      _focusNode.unfocus();
    }
  }

  Future<void> _submit() async {
    if (_focusNode.hasFocus) {
      _skipNextBlurCommit = true;
      _focusNode.unfocus();
    }
    await _commit();
  }

  Future<void> _commit() async {
    if (_saving) return;
    final next = _controller.text.trim();
    if (next.isEmpty) {
      _replaceText(_canonicalValue);
      return;
    }
    if (next == _canonicalValue.trim()) {
      if (_controller.text != _canonicalValue) {
        _replaceText(_canonicalValue);
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSaved(next);
      if (!mounted) return;
      _canonicalValue = next;
      _replaceText(next);
    } catch (error) {
      if (!mounted) return;
      _replaceText(_canonicalValue);
      widget.onSaveError?.call(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
      },
      child: TextField(
        key: const ValueKey('object-inline-title-field'),
        controller: _controller,
        focusNode: _focusNode,
        readOnly: _saving,
        maxLines: 1,
        style: widget.style,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => unawaited(_submit()),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: .7),
          ),
          contentPadding: widget.contentPadding,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
