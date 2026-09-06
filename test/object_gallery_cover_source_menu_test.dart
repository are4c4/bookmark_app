import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_gallery_cover_source_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/widgets/object_gallery_cover_source_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseViewConfig _view({Map<String, dynamic> settings = const {}}) =>
    DatabaseViewConfig(
      id: 1,
      workspaceId: 1,
      databaseKey: 'custom:1',
      name: 'Gallery',
      layoutType: 'gallery',
      filters: const {},
      sorts: const [],
      visibleProperties: const [],
      propertyOrder: const [],
      settings: settings,
      sortOrder: 0,
    );

const _options = <GalleryCoverSourceOption>[
  GalleryCoverSourceOption(
    source: GalleryCoverSource.none(),
    label: 'なし',
  ),
  GalleryCoverSourceOption(
    source: GalleryCoverSource.imageRelation(12),
    label: 'Cover · Image',
  ),
  GalleryCoverSourceOption(
    source: GalleryCoverSource.weblinkRelationRepresentativeImage(18),
    label: 'Sources · Weblinkの代表画像',
  ),
];

void main() {
  testWidgets('persists selected generic Gallery cover source per View',
      (tester) async {
    DatabaseViewConfig? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ObjectGalleryCoverSourceMenu(
              view: _view(
                settings: const {
                  'galleryMode': 'masonry',
                  'openMode': 'sidePeek',
                  'galleryCoverSource': {
                    'kind': 'imageRelation',
                    'relationPropertyId': 12,
                  },
                },
              ),
              options: _options,
              onViewChanged: (next) => changed = next,
            ),
          ),
        ),
      ),
    );

    expect(find.text('カバー: Cover · Image'), findsOneWidget);

    await tester.tap(find.text('カバー: Cover · Image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sources · Weblinkの代表画像'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.settings['galleryMode'], 'masonry');
    expect(changed!.settings['openMode'], 'sidePeek');
    expect(
      const DatabaseViewGalleryAdapter().decodeCoverSource(changed!),
      const GalleryCoverSource.weblinkRelationRepresentativeImage(18),
    );
  });

  testWidgets('stale persisted source falls back visibly to none without writing',
      (tester) async {
    DatabaseViewConfig? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ObjectGalleryCoverSourceMenu(
              view: _view(
                settings: const {
                  'galleryCoverSource': {
                    'kind': 'imageRelation',
                    'relationPropertyId': 999,
                  },
                },
              ),
              options: _options,
              onViewChanged: (next) => changed = next,
            ),
          ),
        ),
      ),
    );

    expect(find.text('カバー: なし'), findsOneWidget);
    expect(changed, isNull);
  });
}
