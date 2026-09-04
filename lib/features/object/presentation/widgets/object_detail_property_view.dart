import 'package:flutter/material.dart';

import '../../../../domain/object_detail_property_presentation.dart';
import 'object_property_value_view.dart';
import 'property_drag_handle.dart';

/// Shared read-oriented Property row for full-page/side/center Object detail.
///
/// Relations deliberately require a caller-provided canonical renderer rather
/// than falling back to persisted ids. Hidden Properties are omitted here so
/// every presentation mode observes the same visibility contract.
class ObjectDetailPropertyView extends StatelessWidget {
  const ObjectDetailPropertyView({
    super.key,
    required this.presentation,
    this.relationChild,
    this.leading,
    this.trailing,
    this.onTap,
  });

  static const double firstLineHeight = 20;
  static const double handleSlotWidth = 20;
  static const double propertyIconSlotWidth = 18;
  static const double propertyLabelWidth = 120;

  final ObjectDetailPropertyPresentation presentation;
  final Widget? relationChild;

  /// Optional presentation chrome owned by the surrounding host. When the host
  /// supplies a standard [ReorderableDragStartListener], this shared row keeps
  /// the host-owned reorder index/gesture while replacing its icon-font child
  /// with the deterministic [PropertyDragHandle] visual.
  final Widget? leading;
  final Widget? trailing;

  /// Optional host-owned edit affordance. The shared row remains read-only by
  /// default so existing full-page/center detail behavior is unchanged.
  final VoidCallback? onTap;

  Widget? _normalizedLeading() {
    final value = leading;
    if (value is ReorderableDragStartListener) {
      return ReorderableDragStartListener(
        key: value.key,
        index: value.index,
        enabled: value.enabled,
        child: const SizedBox(
          width: handleSlotWidth,
          height: firstLineHeight,
          child: Center(child: PropertyDragHandle()),
        ),
      );
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if (presentation.isHidden) {
      return const SizedBox.shrink();
    }

    final property = presentation.property;
    final normalizedLeading = _normalizedLeading();
    final valueWidget = presentation.usesRelationRenderer
        ? relationChild ??
            Text(
              'Relation',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
        : Align(
            alignment: Alignment.centerRight,
            child: ObjectPropertyValueView(presentation: presentation),
          );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (normalizedLeading != null) ...[
            SizedBox(
              key: const ValueKey('object-property-handle-slot'),
              width: handleSlotWidth,
              height: firstLineHeight,
              child: Center(child: normalizedLeading),
            ),
            const SizedBox(width: 6),
          ],
          SizedBox(
            key: const ValueKey('object-property-label-grid'),
            width: propertyLabelWidth,
            height: firstLineHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  key: const ValueKey('object-property-icon-slot'),
                  width: propertyIconSlotWidth,
                  height: firstLineHeight,
                  child: presentation.isComputed
                      ? const Center(child: Icon(Icons.functions, size: 16))
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    property.name,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: valueWidget),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: row,
    );
  }
}
