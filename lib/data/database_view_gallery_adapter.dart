import 'database_view_store.dart';

enum GalleryViewMode {
  fixed,
  masonry;

  static GalleryViewMode fromStorage(Object? value) => switch (value) {
        'masonry' => GalleryViewMode.masonry,
        _ => GalleryViewMode.fixed,
      };

  String get storageValue => switch (this) {
        GalleryViewMode.fixed => 'fixed',
        GalleryViewMode.masonry => 'masonry',
      };
}

/// Persists Gallery geometry as a View setting without creating a second
/// Gallery layout type or changing Object/Database collection semantics.
class DatabaseViewGalleryAdapter {
  const DatabaseViewGalleryAdapter();

  static const settingsKey = 'galleryMode';

  GalleryViewMode decode(DatabaseViewConfig view) =>
      GalleryViewMode.fromStorage(view.settings[settingsKey]);

  DatabaseViewConfig encode(
    DatabaseViewConfig view, {
    required GalleryViewMode mode,
  }) {
    final settings = <String, dynamic>{...view.settings};
    settings[settingsKey] = mode.storageValue;
    return view.copyWith(settings: settings);
  }
}
