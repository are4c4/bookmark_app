import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/object_body_block_contracts.dart';
import '../../../../domain/object_body_block_presentation.dart';

typedef ObjectBodyParagraphSplitCallback = Future<void> Function(
  TextSelection selection,
);

/// Shared Flutter renderer/editor for one Object Body block.
///
/// This widget deliberately depends on the widget-independent presentation
/// model rather than reinterpreting persisted Body payloads in each host.
/// Supplying [onTextChanged] turns known text-like blocks into inline editors;
/// omitting it keeps the same component read-only.
class ObjectBodyBlockView extends StatelessWidget {
  const ObjectBodyBlockView({
    super.key,
    required this.presentation,
    this.onTextChanged,
    this.onParagraphSplit,
    this.onChecklistChanged,
    this.onObjectReferenceTap,
    this.onDatabaseViewTap,
    this.onAssetTap,
    this.autofocus = false,
  });

  final ObjectBodyBlockPresentation presentation;
  final ValueChanged<String>? onTextChanged;
  final ObjectBodyParagraphSplitCallback? onParagraphSplit;
  final ValueChanged<bool>? onChecklistChanged;
  final VoidCallback? onObjectReferenceTap;
  final VoidCallback? onDatabaseViewTap;
  final VoidCallback? onAssetTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final block = presentation.block;
    switch (presentation.kind) {
      case ObjectBodyBlockPresentationKind.text:
        final isParagraph = block.type == ObjectBodyBlockType.paragraph;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _textControl(
            initialValue: block.text ?? '',
            onChanged: onTextChanged,
            onSplit: isParagraph ? onParagraphSplit : null,
            maxLines: isParagraph ? null : 1,
            autofocus: autofocus,
          ),
        );
      case ObjectBodyBlockPresentationKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: _textControl(
            initialValue: block.text ?? '',
            onChanged: onTextChanged,
            style: _headingStyle(context, presentation.headingLevel),
            autofocus: autofocus,
          ),
        );
      case ObjectBodyBlockPresentationKind.checklist:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: presentation.checked ?? false,
              onChanged: onChecklistChanged == null
                  ? null
                  : (value) => onChecklistChanged!(value ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _textControl(
                  initialValue: block.text ?? '',
                  onChanged: onTextChanged,
                  autofocus: autofocus,
                ),
              ),
            ),
          ],
        );
      case ObjectBodyBlockPresentationKind.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (presentation.language case final language?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    language,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              _textControl(
                initialValue: block.text ?? '',
                onChanged: onTextChanged,
                maxLines: null,
                autofocus: autofocus,
              ),
            ],
          ),
        );
      case ObjectBodyBlockPresentationKind.divider:
        return const Divider();
      case ObjectBodyBlockPresentationKind.objectReference:
        return _ReferenceTile(
          icon: Icons.link,
          label: block.text?.trim().isNotEmpty == true
              ? block.text!.trim()
              : 'Object #${block.referencedObjectId ?? '?'}',
          onTap: onObjectReferenceTap,
        );
      case ObjectBodyBlockPresentationKind.databaseView:
        final databaseId = block.referencedDatabaseId;
        final viewId = block.referencedViewId;
        return _ReferenceTile(
          icon: Icons.view_list_outlined,
          label: viewId == null
              ? 'Database #${databaseId ?? '?'}'
              : 'Database #${databaseId ?? '?'} · View #$viewId',
          onTap: onDatabaseViewTap,
        );
      case ObjectBodyBlockPresentationKind.asset:
        final isImage = block.type == ObjectBodyBlockType.image;
        final caption = block.attributes[ObjectBodyBlockAttribute.caption];
        return _ReferenceTile(
          icon: isImage ? Icons.image_outlined : Icons.attach_file,
          label: caption is String && caption.trim().isNotEmpty
              ? caption.trim()
              : '${isImage ? 'Image' : 'File'} #${block.referencedAssetId ?? '?'}',
          onTap: onAssetTap,
        );
      case ObjectBodyBlockPresentationKind.unknown:
        return _ReferenceTile(
          icon: Icons.extension_outlined,
          label: 'Unsupported block: ${block.type}',
        );
    }
  }

  Widget _textControl({
    required String initialValue,
    required ValueChanged<String>? onChanged,
    ObjectBodyParagraphSplitCallback? onSplit,
    TextStyle? style,
    int? maxLines = 1,
    bool autofocus = false,
  }) {
    if (onChanged == null) {
      return Text(initialValue, style: style);
    }
    return _ObjectBodyTextControl(
      key: ValueKey('body-text-${presentation.block.id}'),
      initialValue: initialValue,
      onChanged: onChanged,
      onSplit: onSplit,
      style: style,
      maxLines: maxLines,
      autofocus: autofocus,
    );
  }

  TextStyle? _headingStyle(BuildContext context, int? level) {
    final textTheme = Theme.of(context).textTheme;
    return switch (level) {
      1 => textTheme.headlineSmall,
      2 => textTheme.titleLarge,
      3 => textTheme.titleMedium,
      _ => textTheme.titleLarge,
    };
  }
}

class _ObjectBodyTextControl extends StatefulWidget {
  const _ObjectBodyTextControl({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.maxLines,
    this.onSplit,
    this.style,
    this.autofocus = false,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final ObjectBodyParagraphSplitCallback? onSplit;
  final TextStyle? style;
  final int? maxLines;
  final bool autofocus;

  @override
  State<_ObjectBodyTextControl> createState() => _ObjectBodyTextControlState();
}

class _ObjectBodyTextControlState extends State<_ObjectBodyTextControl> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _splitPending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _requestAutofocusIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ObjectBodyTextControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      final oldOffset = _controller.selection.extentOffset;
      final nextOffset = oldOffset < 0
          ? widget.initialValue.length
          : oldOffset.clamp(0, widget.initialValue.length).toInt();
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: nextOffset),
      );
    }
    if (widget.autofocus && !oldWidget.autofocus) {
      _requestAutofocusIfNeeded();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _requestAutofocusIfNeeded() {
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      style: widget.style,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: widget.onChanged,
    );

    if (widget.onSplit == null) return field;
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: field,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter ||
        _hasActiveComposition) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      _insertLineBreak();
    } else {
      _requestSplit();
    }
    return KeyEventResult.handled;
  }

  bool get _hasActiveComposition {
    final composing = _controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  TextSelection get _normalizedSelection {
    final value = _controller.value;
    final selection = value.selection;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: value.text.length);
    }
    final start = selection.start.clamp(0, value.text.length).toInt();
    final end = selection.end.clamp(start, value.text.length).toInt();
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  void _insertLineBreak() {
    final selection = _normalizedSelection;
    final value = _controller.value;
    final text = value.text.replaceRange(selection.start, selection.end, '\n');
    final offset = selection.start + 1;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
    widget.onChanged(text);
  }

  void _requestSplit() {
    final split = widget.onSplit;
    if (split == null || _splitPending) return;
    _splitPending = true;
    split(_normalizedSelection).whenComplete(() {
      if (mounted) _splitPending = false;
    });
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
