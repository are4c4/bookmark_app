import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_gallery_cover_source_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/widgets/object_gallery_mode_menu.dart';
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

const _coverSources = <GalleryCoverSourceOption>[
  GalleryCoverSourceOption(
    source: GalleryCoverSource.none(),
    label: 'なし',
  ),
  GalleryCoverSourceOption(
    source: GalleryCoverSource.imageRelation(12),
    label: 'Cover · Image',
  ),
];

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

  testWidgets('shared Gallery menu preserves unrelated View settings',
      (tester) async {
    DatabaseViewConfig? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectGalleryModeMenu(
            view: _view(
              settings: const {
                'openMode': 'sidePeek',
                'galleryMode': 'fixed',
              },
            ),
            onViewChanged: (next) => changed = next,
          ),
        ),
      ),
    );

    await tester.tap(find.text('固定比率'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('メイソンリー').last);
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.settings['galleryMode'], 'masonry');
    expect(changed!.settings['openMode'], 'sidePeek');
    expect(changed!.layoutType, 'gallery');
  });

  testWidgets('Gallery toolbar exposes schema-derived cover source choices',
      (tester) async {
    DatabaseViewConfig? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectViewToolbar(
            view: _view(),
            properties: const [],
            galleryCoverSources: _coverSources,
            onViewChanged: (next) => changed = next,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('gallery-cover-source-menu')),
      findsOneWidget,
    );
    expect(find.text('カバー: なし'), findsOneWidget);

    await tester.tap(find.text('カバー: なし'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cover · Image'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(
      const DatabaseViewGalleryAdapter().decodeCoverSource(changed!),
      const GalleryCoverSource.imageRelation(12),
    );
  });

  testWidgets('non-Gallery layouts do not show Gallery controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectViewToolbar(
            view: _view(layoutType: 'table'),
            properties: const [],
            galleryCoverSources: _coverSources,
            onViewChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('gallery-mode-menu')), findsNothing);
    expect(
      find.byKey(const ValueKey('gallery-cover-source-menu')),
      findsNothing,
    );
    expect(find.text('固定比率'), findsNothing);
    expect(find.text('メイソンリー'), findsNothing);
  });
}
