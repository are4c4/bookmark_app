import 'package:flutter/material.dart';

/// Shared Notion-style property row used by database detail panes.
///
/// Every row uses the same four-column geometry:
/// drag handle / property label / value / trailing action.
/// Keeping these widths stable prevents icons, labels and actions from
/// drifting when the value widget changes between properties.
class DetailPropertyRow extends StatefulWidget {
  const DetailPropertyRow({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.onAdd,
    this.addTooltip,
    this.onTapValue,
    this.dragHandle,
  });

  static const double rowHeight = 34;
  static const double handleColumnWidth = 28;
  static const double labelColumnWidth = 188;
  static const double actionColumnWidth = 32;
  static const double propertyIconSize = 16;

  final IconData icon;
  final String label;
  final Widget child;
  final VoidCallback? onAdd;
  final String? addTooltip;
  final VoidCallback? onTapValue;
  final Widget? dragHandle;

  @override
  State<DetailPropertyRow> createState() => _DetailPropertyRowState();
}

class _DetailPropertyRowState extends State<DetailPropertyRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveValueTap = widget.onTapValue ?? widget.onAdd;

    final value = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: DetailPropertyRow.rowHeight),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 12.5,
            height: 1.0,
            color: scheme.onSurface,
          ),
          child: widget.child,
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        decoration: BoxDecoration(
          color: _hovered ? scheme.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              key: const ValueKey('detail-property-handle-column'),
              width: DetailPropertyRow.handleColumnWidth,
              height: DetailPropertyRow.rowHeight,
              child: widget.dragHandle == null
                  ? const SizedBox.shrink()
                  : AnimatedOpacity(
                      duration: const Duration(milliseconds: 90),
                      opacity: _hovered ? 1 : .28,
                      child: Center(child: widget.dragHandle),
                    ),
            ),
            SizedBox(
              key: const ValueKey('detail-property-label-column'),
              width: DetailPropertyRow.labelColumnWidth,
              height: DetailPropertyRow.rowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        widget.icon,
                        size: DetailPropertyRow.propertyIconSize,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
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
              key: const ValueKey('detail-property-value-column'),
              child: effectiveValueTap == null
                  ? value
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: effectiveValueTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: value,
                        ),
                      ),
                    ),
            ),
            SizedBox(
              key: const ValueKey('detail-property-action-column'),
              width: DetailPropertyRow.actionColumnWidth,
              height: DetailPropertyRow.rowHeight,
              child: widget.onAdd == null
                  ? const SizedBox.shrink()
                  : AnimatedOpacity(
                      duration: const Duration(milliseconds: 90),
                      opacity: _hovered ? 1 : .50,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tooltip: widget.addTooltip,
                        onPressed: widget.onAdd,
                        icon: Icon(
                          Icons.add,
                          size: 17,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ],
        ),
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
        height: DetailPropertyRow.rowHeight,
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
            SizedBox(
              width: DetailPropertyRow.actionColumnWidth,
              height: DetailPropertyRow.rowHeight,
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
