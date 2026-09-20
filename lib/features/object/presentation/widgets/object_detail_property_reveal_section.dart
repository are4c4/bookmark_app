import 'package:flutter/material.dart';

/// Shared presentation boundary for collapsing optional empty Property rows.
///
/// The caller remains responsible for classifying Property semantics. In
/// particular, Relation/computed values should only be placed in
/// [emptyChildren] after their canonical empty-state semantics are proven.
class ObjectDetailPropertyRevealSection extends StatefulWidget {
  const ObjectDetailPropertyRevealSection({
    super.key,
    required this.visibleChildren,
    required this.emptyChildren,
  });

  final List<Widget> visibleChildren;
  final List<Widget> emptyChildren;

  @override
  State<ObjectDetailPropertyRevealSection> createState() =>
      _ObjectDetailPropertyRevealSectionState();
}

class _ObjectDetailPropertyRevealSectionState
    extends State<ObjectDetailPropertyRevealSection> {
  final FocusNode _toggleFocusNode = FocusNode();
  bool _showEmpty = false;

  @override
  void dispose() {
    _toggleFocusNode.dispose();
    super.dispose();
  }

  void _setShowEmpty(bool value) {
    final hadFocus = _toggleFocusNode.hasFocus;
    setState(() => _showEmpty = value);
    if (hadFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEmpty = widget.emptyChildren.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...widget.visibleChildren,
        if (hasEmpty && !_showEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              key: const ValueKey('object-detail-empty-properties-disclosure'),
              expanded: false,
              child: TextButton.icon(
                key: const ValueKey('object-detail-show-empty-properties'),
                focusNode: _toggleFocusNode,
                onPressed: () => _setShowEmpty(true),
                icon: const Icon(Icons.unfold_more, size: 16),
                label: Text('空のプロパティを表示 (${widget.emptyChildren.length})'),
              ),
            ),
          ),
        if (hasEmpty && _showEmpty) ...[
          ...widget.emptyChildren,
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              key: const ValueKey('object-detail-empty-properties-disclosure'),
              expanded: true,
              child: TextButton.icon(
                key: const ValueKey('object-detail-hide-empty-properties'),
                focusNode: _toggleFocusNode,
                onPressed: () => _setShowEmpty(false),
                icon: const Icon(Icons.unfold_less, size: 16),
                label: const Text('空のプロパティを隠す'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
