import 'package:flutter/material.dart';

/// Reusable right-side detail pane with a Notion-like draggable divider.
/// Width is remembered per [storageKey] for the lifetime of the app.
class ResizableDetailPane extends StatefulWidget {
  const ResizableDetailPane({
    super.key,
    required this.storageKey,
    required this.child,
    this.initialWidth = 400,
    this.minWidth = 320,
    this.maxWidth = 720,
    this.dividerWidth = 6,
  });

  final String storageKey;
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final double dividerWidth;

  @override
  State<ResizableDetailPane> createState() => _ResizableDetailPaneState();
}

class _ResizableDetailPaneState extends State<ResizableDetailPane> {
  static final Map<String, double> _rememberedWidths = <String, double>{};
  late double _width;

  @override
  void initState() {
    super.initState();
    _width = (_rememberedWidths[widget.storageKey] ?? widget.initialWidth)
        .clamp(widget.minWidth, widget.maxWidth)
        .toDouble();
  }

  void _resize(double delta) {
    setState(() {
      _width = (_width - delta).clamp(widget.minWidth, widget.maxWidth).toDouble();
      _rememberedWidths[widget.storageKey] = _width;
    });
  }

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
