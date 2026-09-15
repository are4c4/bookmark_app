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
  static const double minPropertyLabelWidth = 96;
  static const double maxPropertyLabelWidth = 220;
  static const double propertyLabelWidthFraction = 0.32;

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

  double _propertyLabelWidth(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) {
      return maxPropertyLabelWidth;
    }
    return (constraints.maxWidth * propertyLabelWidthFraction).clamp(
      minPropertyLabelWidth,
      maxPropertyLabelWidth,
    );
  }

  bool get _hasEmptyScalarValue {
    if (presentation.usesRelationRenderer || presentation.isComputed) {
      return false;
    }
    final value = presentation.value;
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  Widget _quietEmptyRow(BuildContext context) {
    final property = presentation.property;
    final canAccess = trailing != null || onTap != null;
    if (!canAccess) {
      return const SizedBox.shrink();
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              property.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      key: const ValueKey('object-property-empty-affordance'),
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (presentation.isHidden) {
      return const SizedBox.shrink();
    }

    // Read-oriented Object detail should prioritize meaningful content. Empty
    // scalar metadata without an edit affordance disappears entirely; editable
    // empty values remain reachable as a quiet compact label/chrome row. Hosts
    // that supply leading row-management chrome (for example Database schema
    // editing/reordering) retain the full row so this presentation policy does
    // not hide their structure-management surface.
    if (leading == null && _hasEmptyScalarValue) {
      return _quietEmptyRow(context);
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

    final row = LayoutBuilder(
      builder: (context, constraints) {
        final propertyLabelWidth = _propertyLabelWidth(constraints);
        return Padding(
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
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        );
      },
    );

    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: row,
    );
  }
}
