import 'package:flutter/material.dart';

/// Contextual chrome for rendering shared Object detail content in a side pane.
///
/// The shell intentionally owns only presentation actions. The supplied [child]
/// remains the same Object detail surface used by center-peek/full-page hosts.
class ObjectSidePeekShell extends StatelessWidget {
  const ObjectSidePeekShell({
    super.key,
    required this.child,
    required this.onOpenFullPage,
    required this.onClose,
  });

  final Widget child;
  final VoidCallback onOpenFullPage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Text(
                  '詳細',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('object-side-peek-open-full-page'),
                  tooltip: 'フルページで開く',
                  icon: const Icon(Icons.open_in_full, size: 18),
                  onPressed: onOpenFullPage,
                ),
                IconButton(
                  key: const ValueKey('object-side-peek-close'),
                  tooltip: '閉じる',
                  icon: const Icon(Icons.close, size: 19),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(child: child),
        ],
      ),
    );
  }
}
