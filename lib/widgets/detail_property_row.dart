import 'package:flutter/material.dart';

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
      constraints: const BoxConstraints(minHeight: 30),
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.dragHandle != null)
              SizedBox(
                width: 22,
                height: 30,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  opacity: _hovered ? 1 : .25,
                  child: widget.dragHandle,
                ),
              ),
            SizedBox(
              width: widget.dragHandle == null ? 112 : 100,
              height: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 7),
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
              child: effectiveValueTap == null
                  ? value
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: effectiveValueTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: value,
                        ),
                      ),
                    ),
            ),
            if (widget.onAdd != null)
              SizedBox(
                width: 28,
                height: 30,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  opacity: _hovered ? 1 : .52,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: widget.addTooltip,
                    onPressed: widget.onAdd,
                    icon: Icon(Icons.add, size: 17, color: scheme.onSurfaceVariant),
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
            SizedBox(
              width: 28,
              height: 30,
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
