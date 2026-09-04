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
}
