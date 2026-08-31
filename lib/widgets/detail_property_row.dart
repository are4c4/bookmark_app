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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 112,
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 7),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.0,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.0,
                    color: scheme.onSurface,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
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
    );
  }
}

class DetailSelectField<T> extends StatelessWidget {
  const DetailSelectField({
    super.key,
    required this.value,
    required this.items,
    required this.onSelected,
    this.empty = false,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onSelected;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = items[value] ?? value.toString();
    final textColor = empty
        ? scheme.onSurfaceVariant.withValues(alpha: .55)
        : scheme.onSurface;

    return PopupMenuButton<T>(
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => items.entries
          .map(
            (entry) => PopupMenuItem<T>(
              value: entry.key,
              height: 36,
              child: Text(entry.value, style: const TextStyle(fontSize: 12.5)),
            ),
          )
          .toList(),
      child: SizedBox(
        height: 30,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.0,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
