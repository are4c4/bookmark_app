import 'package:flutter/material.dart';

/// Deterministic 2 x 3 drag-handle visual for Property rows.
///
/// This deliberately avoids Material icon-font metrics so the visible dots stay
/// optically centered across platforms, fonts, device pixel ratios and hosts.
class PropertyDragHandle extends StatelessWidget {
  const PropertyDragHandle({
    super.key,
    this.color,
  });

  static const double width = 12;
  static const double height = 18;
  static const double dotDiameter = 2.5;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .55);
    const centersX = <double>[3, 9];
    const centersY = <double>[3, 9, 15];
    const radius = dotDiameter / 2;

    return SizedBox(
      key: const ValueKey('property-six-dot-handle'),
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var row = 0; row < centersY.length; row++)
            for (var column = 0; column < centersX.length; column++)
              Positioned(
                left: centersX[column] - radius,
                top: centersY[row] - radius,
                child: DecoratedBox(
                  key: ValueKey('property-six-dot-$row-$column'),
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: dotDiameter),
                ),
              ),
        ],
      ),
    );
  }
}
