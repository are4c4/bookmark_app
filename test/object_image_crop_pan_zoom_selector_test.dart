import 'package:bookmark_app/features/object/presentation/widgets/object_image_crop_pan_zoom_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pan moves the source opposite to the dragged image direction', () {
    const source = Rect.fromLTWH(0.2, 0.2, 0.5, 0.5);
    final moved = ObjectImageCropPanZoomGeometry.panSource(
      source,
      source,
      const Offset(-20, 10),
      const Size(200, 100),
    );

    expect(moved.left, closeTo(0.3, 0.0001));
    expect(moved.top, closeTo(0.1, 0.0001));
    expect(moved.width, closeTo(0.5, 0.0001));
    expect(moved.height, closeTo(0.5, 0.0001));
  });

  test('wheel zoom preserves source aspect ratio and normalized bounds', () {
    const source = Rect.fromLTWH(0.2, 0.25, 0.5, 0.4);
    final zoomed = ObjectImageCropPanZoomGeometry.zoomSource(source, -100);

    expect(zoomed.width, lessThan(source.width));
    expect(zoomed.height, lessThan(source.height));
    expect(
      zoomed.width / zoomed.height,
      closeTo(source.width / source.height, 0.0001),
    );
    expect(zoomed.left, greaterThanOrEqualTo(0));
    expect(zoomed.top, greaterThanOrEqualTo(0));
    expect(zoomed.right, lessThanOrEqualTo(1));
    expect(zoomed.bottom, lessThanOrEqualTo(1));
  });

  test('zoom refuses to shrink either source axis below minimum size', () {
    final zoomed = ObjectImageCropPanZoomGeometry.zoomSource(
      const Rect.fromLTWH(0.2, 0.2, 0.2, 0.1),
      -10000,
      minCropSize: 0.08,
    );

    expect(zoomed.width, greaterThanOrEqualTo(0.08));
    expect(zoomed.height, greaterThanOrEqualTo(0.08));
  });

  testWidgets('dragging fixed frame pans the emitted source rectangle',
      (tester) async {
    Rect? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: ObjectImageCropPanZoomSelector(
              initialRect: const Rect.fromLTWH(0.2, 0.2, 0.5, 0.5),
              onChanged: (value) => changed = value,
              child: const ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('object-image-free-crop-pan-zoom-selector')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('object-image-free-crop-pan-zoom-frame')),
      const Offset(-20, 0),
    );
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.left, closeTo(0.3, 0.02));
    expect(changed!.top, closeTo(0.2, 0.001));
    expect(changed!.width, closeTo(0.5, 0.001));
    expect(changed!.height, closeTo(0.5, 0.001));
  });
}
