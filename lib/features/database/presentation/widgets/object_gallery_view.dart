import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../data/database_view_gallery_adapter.dart';

/// Shared Gallery geometry renderer.
///
/// Both modes consume the same item builder so switching presentation never
/// changes Object identity, projection, filtering, sorting or opening behavior.
class ObjectGalleryView extends StatelessWidget {
  const ObjectGalleryView({
    super.key,
    required this.mode,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 80),
    this.maxCrossAxisExtent = 280,
    this.fixedMainAxisExtent = 180,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
  });

  final GalleryViewMode mode;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final double maxCrossAxisExtent;
  final double fixedMainAxisExtent;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    if (mode == GalleryViewMode.masonry) {
      return MasonryGridView.extent(
        key: const ValueKey('object-gallery-masonry'),
        padding: padding,
        maxCrossAxisExtent: maxCrossAxisExtent,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    }

    return GridView.builder(
      key: const ValueKey('object-gallery-fixed'),
      padding: padding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisExtent: fixedMainAxisExtent,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
