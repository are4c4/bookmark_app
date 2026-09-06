import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
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

void main() {
  const adapter = DatabaseViewGalleryAdapter();

  test('Gallery mode defaults to fixed for missing or malformed settings', () {
    expect(adapter.decode(_view()), GalleryViewMode.fixed);
    expect(
      adapter.decode(_view(settings: const {'galleryMode': 'unknown'})),
      GalleryViewMode.fixed,
    );
  });

  test('Gallery mode round-trips per View without changing layout identity', () {
    final encoded = adapter.encode(
      _view(settings: const {'openMode': 'sidePeek'}),
      mode: GalleryViewMode.masonry,
    );

    expect(encoded.layoutType, 'gallery');
    expect(encoded.settings['galleryMode'], 'masonry');
    expect(encoded.settings['openMode'], 'sidePeek');
    expect(adapter.decode(encoded), GalleryViewMode.masonry);

    final fixed = adapter.encode(encoded, mode: GalleryViewMode.fixed);
    expect(fixed.settings['galleryMode'], 'fixed');
    expect(fixed.settings['openMode'], 'sidePeek');
    expect(adapter.decode(fixed), GalleryViewMode.fixed);
  });

  test('Gallery cover source defaults to none for missing or malformed settings', () {
    expect(adapter.decodeCoverSource(_view()), const GalleryCoverSource.none());
    expect(
      adapter.decodeCoverSource(
        _view(
          settings: const {
            'galleryCoverSource': {'kind': 'imageRelation'},
          },
        ),
      ),
      const GalleryCoverSource.none(),
    );
    expect(
      adapter.decodeCoverSource(
        _view(
          settings: const {
            'galleryCoverSource': {
              'kind': 'weblinkRelationRepresentativeImage',
              'relationPropertyId': 0,
            },
          },
        ),
      ),
      const GalleryCoverSource.none(),
    );
  });

  test('Gallery cover source round-trips independently from Gallery geometry', () {
    final initial = _view(
      settings: const {
        'galleryMode': 'masonry',
        'openMode': 'sidePeek',
      },
    );

    final imageRelation = adapter.encodeCoverSource(
      initial,
      source: const GalleryCoverSource.imageRelation(42),
    );

    expect(imageRelation.layoutType, 'gallery');
    expect(imageRelation.settings['galleryMode'], 'masonry');
    expect(imageRelation.settings['openMode'], 'sidePeek');
    expect(
      imageRelation.settings['galleryCoverSource'],
      const {
        'kind': 'imageRelation',
        'relationPropertyId': 42,
      },
    );
    expect(
      adapter.decodeCoverSource(imageRelation),
      const GalleryCoverSource.imageRelation(42),
    );

    final weblinkRelation = adapter.encodeCoverSource(
      imageRelation,
      source: const GalleryCoverSource.weblinkRelationRepresentativeImage(7),
    );
    expect(
      adapter.decodeCoverSource(weblinkRelation),
      const GalleryCoverSource.weblinkRelationRepresentativeImage(7),
    );

    final direct = adapter.encodeCoverSource(
      weblinkRelation,
      source: const GalleryCoverSource.directImage(),
    );
    expect(
      adapter.decodeCoverSource(direct),
      const GalleryCoverSource.directImage(),
    );

    final none = adapter.encodeCoverSource(
      direct,
      source: const GalleryCoverSource.none(),
    );
    expect(
      adapter.decodeCoverSource(none),
      const GalleryCoverSource.none(),
    );
  });
}
