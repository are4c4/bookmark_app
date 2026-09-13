import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../services/ui_layout_preferences.dart';

/// Reusable right-side detail pane with a Notion-like draggable divider.
///
/// Width is persisted as local presentation state and restored across widget/
/// process recreation. Persistence happens only when a drag gesture completes,
/// not for every pixel update.
class ResizableDetailPane extends StatefulWidget {
  const ResizableDetailPane({
    super.key,
    required this.storageKey,
    required this.child,
    this.initialWidth = 400,
    this.minWidth = 320,
    this.maxWidth = 720,
    this.dividerWidth = 6,
    this.preferences = const UiLayoutPreferences(),
  });

  final String storageKey;
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final double dividerWidth;
  final UiLayoutPreferences preferences;

  @override
  State<ResizableDetailPane> createState() => _ResizableDetailPaneState();
}

class _ResizableDetailPaneState extends State<ResizableDetailPane> {
  late double _width;
  var _restoreSerial = 0;

  @override
  void initState() {
    super.initState();
    _width = _clamp(widget.initialWidth);
    unawaited(_restoreWidth());
  }

  @override
  void didUpdateWidget(covariant ResizableDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey ||
        oldWidget.preferences != widget.preferences) {
      _width = _clamp(widget.initialWidth);
      unawaited(_restoreWidth());
      return;
    }
    if (oldWidget.minWidth != widget.minWidth ||
        oldWidget.maxWidth != widget.maxWidth) {
      setState(() => _width = _clamp(_width));
    }
  }

  double _clamp(double value) =>
      value.clamp(widget.minWidth, widget.maxWidth).toDouble();

  Future<void> _restoreWidth() async {
    final serial = ++_restoreSerial;
    final storageKey = widget.storageKey;
    final saved = await widget.preferences.loadDetailPaneWidth(storageKey);
    if (!mounted || serial != _restoreSerial || storageKey != widget.storageKey) {
      return;
    }
    setState(() => _width = _clamp(saved ?? widget.initialWidth));
  }

  void _resize(double delta) {
    setState(() => _width = _clamp(_width - delta));
  }

  Future<void> _persistWidth() =>
      widget.preferences.saveDetailPaneWidth(widget.storageKey, _width);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) => _resize(details.delta.dx),
            onHorizontalDragEnd: (_) => unawaited(_persistWidth()),
            onHorizontalDragCancel: () => unawaited(_persistWidth()),
            child: SizedBox(
              width: widget.dividerWidth,
              child: Center(
                child: Container(width: 1, color: scheme.outlineVariant),
              ),
            ),
          ),
        ),
        SizedBox(width: _width, child: widget.child),
      ],
    );
  }
}
