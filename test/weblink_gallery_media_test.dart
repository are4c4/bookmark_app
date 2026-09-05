import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/features/database/presentation/widgets/weblink_gallery_media.dart';
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

  testWidgets('masonry frame preserves supplied media aspect ratio', (tester) async {
    await tester.pumpWidget(
      host(
        const WeblinkGalleryMediaFrame(
          objectId: 10,
          mode: GalleryViewMode.masonry,
          aspectRatio: .5,
          child: ColoredBox(color: Colors.black12),
        ),
      ),
    );

    final portrait = find.byKey(
      const ValueKey('weblink-gallery-media-ratio-10'),
    );
    expect(portrait, findsOneWidget);
    expect(tester.getSize(portrait).height, closeTo(440, .1));

    await tester.pumpWidget(
      host(
        const WeblinkGalleryMediaFrame(
          objectId: 11,
          mode: GalleryViewMode.masonry,
          aspectRatio: 2,
          child: ColoredBox(color: Colors.black12),
        ),
      ),
    );
    final landscape = find.byKey(
      const ValueKey('weblink-gallery-media-ratio-11'),
    );
    expect(landscape, findsOneWidget);
    expect(tester.getSize(landscape).height, closeTo(110, .1));
  });

  testWidgets('masonry frame uses stable fallback without geometry', (tester) async {
    await tester.pumpWidget(
      host(
        const WeblinkGalleryMediaFrame(
          objectId: 20,
          mode: GalleryViewMode.masonry,
          child: ColoredBox(color: Colors.black12),
        ),
      ),
    );

    final fallback = find.byKey(
      const ValueKey('weblink-gallery-media-fallback-20'),
    );
    expect(fallback, findsOneWidget);
    expect(tester.getSize(fallback).height, 160);
  });

  testWidgets('fixed frame ignores intrinsic ratio and stays uniform', (tester) async {
    await tester.pumpWidget(
      host(
        const WeblinkGalleryMediaFrame(
          objectId: 30,
          mode: GalleryViewMode.fixed,
          aspectRatio: .5,
          child: ColoredBox(color: Colors.black12),
        ),
      ),
    );

    final fixed = find.byKey(
      const ValueKey('weblink-gallery-media-fixed-30'),
    );
    expect(fixed, findsOneWidget);
    expect(tester.getSize(fixed).height, 96);
  });
}
