import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/features/database/presentation/widgets/object_gallery_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(GalleryViewMode mode) {
    const heights = <double>[80, 160, 110, 210];
    return MaterialApp(
      home: Scaffold(
        body: ObjectGalleryView(
          mode: mode,
          itemCount: heights.length,
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey('gallery-item-$index'),
            height: heights[index],
            child: Text('Item $index'),
          ),
        ),
      ),
    );
  }

  testWidgets('fixed Gallery forces uniform card geometry', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(GalleryViewMode.fixed));
    await tester.pump();

    expect(find.byKey(const ValueKey('object-gallery-fixed')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-gallery-masonry')), findsNothing);
    for (var index = 0; index < 4; index++) {
      expect(
        tester.getSize(find.byKey(ValueKey('gallery-item-$index'))).height,
        240,
      );
    }
  });

  testWidgets('masonry Gallery preserves mixed item heights', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(GalleryViewMode.masonry));
    await tester.pump();

    expect(find.byKey(const ValueKey('object-gallery-masonry')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-gallery-fixed')), findsNothing);
    expect(
      <double>[
        for (var index = 0; index < 4; index++)
          tester.getSize(find.byKey(ValueKey('gallery-item-$index'))).height,
      ],
      <double>[80, 160, 110, 210],
    );
  });
}
