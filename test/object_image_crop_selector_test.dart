import 'package:bookmark_app/features/object/presentation/widgets/object_image_crop_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('move keeps normalized crop inside the unit square', () {
    final moved = ObjectImageCropGeometry.move(
      const Rect.fromLTWH(0.2, 0.2, 0.5, 0.5),
      const Offset(400, 300),
      const Size(200, 100),
    );

    expect(moved.left, closeTo(0.5, 0.0001));
    expect(moved.top, closeTo(0.5, 0.0001));
    expect(moved.right, closeTo(1.0, 0.0001));
    expect(moved.bottom, closeTo(1.0, 0.0001));
  });

  test('resize keeps the minimum free-crop size', () {
    final resized = ObjectImageCropGeometry.resize(
      const Rect.fromLTWH(0.2, 0.2, 0.5, 0.5),
      ObjectImageCropHandle.topLeft,
      const Offset(500, 500),
      const Size(200, 100),
      minCropSize: 0.1,
    );

    expect(resized.width, closeTo(0.1, 0.0001));
    expect(resized.height, closeTo(0.1, 0.0001));
    expect(resized.right, closeTo(0.7, 0.0001));
    expect(resized.bottom, closeTo(0.7, 0.0001));
  });

  test('edge resize changes only its matching axis', () {
    const source = Rect.fromLTWH(0.2, 0.2, 0.5, 0.5);
    final resized = ObjectImageCropGeometry.resize(
      source,
      ObjectImageCropHandle.right,
      const Offset(-40, 30),
      const Size(200, 100),
    );

    expect(resized.left, source.left);
    expect(resized.top, source.top);
    expect(resized.bottom, source.bottom);
    expect(resized.right, closeTo(0.5, 0.0001));
  });

  test('edge resize enforces minimum size on one axis', () {
    final resized = ObjectImageCropGeometry.resize(
      const Rect.fromLTWH(0.2, 0.2, 0.5, 0.5),
      ObjectImageCropHandle.top,
      const Offset(20, 500),
      const Size(200, 100),
      minCropSize: 0.1,
    );

    expect(resized.height, closeTo(0.1, 0.0001));
    expect(resized.left, closeTo(0.2, 0.0001));
    expect(resized.right, closeTo(0.7, 0.0001));
    expect(resized.bottom, closeTo(0.7, 0.0001));
  });

  test('invalid initial geometry falls back to a safe normalized rectangle', () {
    final normalized = ObjectImageCropGeometry.normalize(
      Rect.fromLTRB(double.nan, 0, 1, 1),
    );

    expect(normalized, ObjectImageCropGeometry.defaultRect);
  });

  testWidgets('dragging crop frame reports normalized movement', (tester) async {
    Rect? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: ObjectImageCropSelector(
              onChanged: (value) => changed = value,
              child: const ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('object-image-free-crop-frame')),
      const Offset(20, 10),
    );
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.left, closeTo(0.16, 0.02));
    expect(changed!.top, closeTo(0.16, 0.02));
    expect(changed!.width, closeTo(0.84, 0.001));
    expect(changed!.height, closeTo(0.84, 0.001));
  });

  testWidgets('corner handle resizes freely in both axes', (tester) async {
    Rect? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: ObjectImageCropSelector(
              onChanged: (value) => changed = value,
              child: const ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(
        const ValueKey('object-image-free-crop-handle-bottom-right'),
      ),
      const Offset(-20, -10),
    );
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.right, closeTo(0.82, 0.02));
    expect(changed!.bottom, closeTo(0.82, 0.02));
    expect(changed!.width, lessThan(0.84));
    expect(changed!.height, lessThan(0.84));
  });

  testWidgets('edge handle resizes only one axis', (tester) async {
    Rect? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: ObjectImageCropSelector(
              onChanged: (value) => changed = value,
              child: const ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('object-image-free-crop-handle-right')),
      const Offset(-20, 20),
    );
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.right, closeTo(0.82, 0.02));
    expect(changed!.top, closeTo(0.08, 0.001));
    expect(changed!.bottom, closeTo(0.92, 0.001));
    expect(changed!.height, closeTo(0.84, 0.001));
  });
}
