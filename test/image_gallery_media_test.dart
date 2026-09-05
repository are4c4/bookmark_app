import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/features/database/presentation/widgets/image_gallery_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 220, child: child),
          ),
        ),
      );

  testWidgets('masonry frame preserves portrait and landscape geometry',
      (tester) async {
    await tester.pumpWidget(
      host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageGalleryMediaFrame(
              objectId: 1,
              mode: GalleryViewMode.masonry,
              aspectRatio: .5,
              child: SizedBox.expand(),
            ),
            ImageGalleryMediaFrame(
              objectId: 2,
              mode: GalleryViewMode.masonry,
              aspectRatio: 2,
              child: SizedBox.expand(),
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('image-gallery-media-ratio-1'))),
      const Size(220, 440),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('image-gallery-media-ratio-2'))),
      const Size(220, 110),
    );
  });

  testWidgets('masonry frame uses stable fallback without valid geometry',
      (tester) async {
    await tester.pumpWidget(
      host(
        const ImageGalleryMediaFrame(
          objectId: 3,
          mode: GalleryViewMode.masonry,
          child: SizedBox.expand(),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('image-gallery-media-fallback-3'))),
      const Size(220, 160),
    );
  });

  testWidgets('fixed frame ignores persisted aspect ratio', (tester) async {
    await tester.pumpWidget(
      host(
        const ImageGalleryMediaFrame(
          objectId: 4,
          mode: GalleryViewMode.fixed,
          aspectRatio: .5,
          child: SizedBox.expand(),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('image-gallery-media-fixed-4'))),
      const Size(220, 96),
    );
  });
}
