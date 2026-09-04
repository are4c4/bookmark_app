import 'package:flutter/material.dart';

import '../../../../domain/object_detail_property_presentation.dart';
import 'object_property_value_view.dart';

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

  final ObjectDetailPropertyPresentation presentation;
  final Widget? relationChild;

  /// Optional presentation chrome owned by the surrounding host, such as the
  /// drag handle used by the contextual Database side peek.
  final Widget? leading;
  final Widget? trailing;

  /// Optional host-owned edit affordance. The shared row remains read-only by
  /// default so existing full-page/center detail behavior is unchanged.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (presentation.isHidden) {
      return const SizedBox.shrink();
    }

    final property = presentation.property;
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
          if (leading != null) ...[
            SizedBox(
              width: 20,
              height: 20,
              child: Align(
                // Material's drag-indicator glyph is optically top-heavy.
                // Keep a stable label-row-sized slot and lower the glyph by
                // roughly one pixel without changing the host-owned handle.
                alignment: const Alignment(0, 0.2),
                child: leading!,
              ),
            ),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (presentation.isComputed)
                  const Padding(
                    padding: EdgeInsets.only(top: 1, right: 4),
                    child: Icon(Icons.functions, size: 16),
                  ),
                Expanded(
                  child: Text(
                    property.name,
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
