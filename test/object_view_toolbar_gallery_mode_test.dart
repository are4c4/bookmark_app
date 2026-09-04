import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/widgets/object_view_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseViewConfig _view({
  String layoutType = 'gallery',
  Map<String, dynamic> settings = const {},
}) => DatabaseViewConfig(
      id: 1,
      workspaceId: 1,
      databaseKey: 'custom:1',
      name: 'Gallery',
      layoutType: layoutType,
      filters: const {},
      sorts: const [],
      visibleProperties: const [],
      propertyOrder: const [],
      settings: settings,
      sortOrder: 0,
    );

void main() {
  testWidgets('Gallery toolbar persists fixed or masonry through View settings',
      (tester) async {
    DatabaseViewConfig? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectViewToolbar(
            view: _view(),
            properties: const [],
            onViewChanged: (next) => changed = next,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('gallery-mode-menu')), findsOneWidget);
    expect(find.text('固定比率'), findsOneWidget);

    await tester.tap(find.text('固定比率'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('メイソンリー').last);
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.layoutType, 'gallery');
    expect(
      const DatabaseViewGalleryAdapter().decode(changed!),
      GalleryViewMode.masonry,
    );
  });

  testWidgets('non-Gallery layouts do not show the Gallery geometry control',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectViewToolbar(
            view: _view(layoutType: 'table'),
            properties: const [],
            onViewChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('gallery-mode-menu')), findsNothing);
    expect(find.text('固定比率'), findsNothing);
    expect(find.text('メイソンリー'), findsNothing);
  });
}
