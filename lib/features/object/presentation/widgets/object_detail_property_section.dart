import 'package:flutter/material.dart';

import '../../../../domain/object_detail_property_presentation.dart';
import '../object_detail_empty_property_policy.dart';
import 'object_detail_property_reveal_section.dart';

/// Shared composition boundary for Object-detail Property presentation.
///
/// This keeps the canonical empty-Property policy and the reveal interaction
/// together so full-page and Side Peek hosts cannot accidentally classify the
/// same Property differently. The host still owns the actual row renderer and
/// edit/relation affordances.
class ObjectDetailPropertySection extends StatelessWidget {
  const ObjectDetailPropertySection({
    super.key,
    required this.presentations,
    required this.itemBuilder,
  });

  final List<ObjectDetailPropertyPresentation> presentations;
  final Widget Function(
    BuildContext context,
    ObjectDetailPropertyPresentation presentation,
  )
  itemBuilder;

  @override
  Widget build(BuildContext context) {
    final visible = <Widget>[];
    final empty = <Widget>[];

    for (final presentation in presentations) {
      if (presentation.isHidden) continue;
      final child = itemBuilder(context, presentation);
      if (ObjectDetailEmptyPropertyPolicy.isCollapsibleEmpty(presentation)) {
        empty.add(child);
      } else {
        visible.add(child);
      }
    }

    return ObjectDetailPropertyRevealSection(
      visibleChildren: visible,
      emptyChildren: empty,
    );
  }
}
