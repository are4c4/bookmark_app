import 'package:bookmark_app/features/object/presentation/widgets/object_image_detail_preview.dart';
import 'package:bookmark_app/services/image_visual_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Image detail preview content uses resolved path and geometry',
      (tester) async {
    const visual = ImageManagedVisual(
      imageObjectId: 7,
      filePath: '/resolved/profile/photos/preview.png',
      pixelWidth: 800,
      pixelHeight: 400,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageDetailPreviewContent(
            objectId: visual.imageObjectId,
            isLoading: false,
            visual: visual,
            imageBuilder: (_, path) => Text(
              path,
              key: const ValueKey('resolved-image-path'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('object-image-preview-7')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('resolved-image-path')), findsOneWidget);
    expect(find.text(visual.filePath), findsOneWidget);
    final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, 2);
  });

  testWidgets('Image detail preview content surfaces missing media safely',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectImageDetailPreviewContent(
            objectId: 8,
            isLoading: false,
            visual: null,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('object-image-preview-missing-8')),
      findsOneWidget,
    );
    expect(find.text('画像ファイルを表示できません'), findsOneWidget);
  });

  testWidgets('Image detail preview content exposes bounded loading surface',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectImageDetailPreviewContent(
            objectId: 9,
            isLoading: true,
            visual: null,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('object-image-preview-loading-9')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
