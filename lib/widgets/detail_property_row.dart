import 'package:flutter/material.dart';

class DetailPropertyRow extends StatelessWidget {
  const DetailPropertyRow({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.onAdd,
    this.addTooltip,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final VoidCallback? onAdd;
  final String? addTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 112,
              child: Row(children: [
                Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(child: child),
            SizedBox(
              width: 30,
              height: 30,
              child: onAdd == null
                  ? null
                  : IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: addTooltip,
                      onPressed: onAdd,
                      icon: Icon(Icons.add, size: 17, color: scheme.onSurfaceVariant),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
