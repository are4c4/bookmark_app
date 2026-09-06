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

enum GalleryCoverSourceKind {
  none,
  directImage,
  imageRelation,
  weblinkRelationRepresentativeImage;

  static GalleryCoverSourceKind? fromStorage(Object? value) => switch (value) {
        'none' => GalleryCoverSourceKind.none,
        'directImage' => GalleryCoverSourceKind.directImage,
        'imageRelation' => GalleryCoverSourceKind.imageRelation,
        'weblinkRelationRepresentativeImage' =>
          GalleryCoverSourceKind.weblinkRelationRepresentativeImage,
        _ => null,
      };

  String get storageValue => switch (this) {
        GalleryCoverSourceKind.none => 'none',
        GalleryCoverSourceKind.directImage => 'directImage',
        GalleryCoverSourceKind.imageRelation => 'imageRelation',
        GalleryCoverSourceKind.weblinkRelationRepresentativeImage =>
          'weblinkRelationRepresentativeImage',
      };
}

/// Generic, per-View media source used by Gallery presentation.
///
/// Relation-backed sources identify the Relation Property in the source
/// ObjectType schema. Resolution of the target Object/media stays outside this
/// persistence adapter so both fixed and masonry Gallery layouts can consume
/// the same configuration contract.
class GalleryCoverSource {
  const GalleryCoverSource._({
    required this.kind,
    this.relationPropertyId,
  });

  const GalleryCoverSource.none()
      : kind = GalleryCoverSourceKind.none,
        relationPropertyId = null;

  const GalleryCoverSource.directImage()
      : kind = GalleryCoverSourceKind.directImage,
        relationPropertyId = null;

  const GalleryCoverSource.imageRelation(int propertyId)
      : kind = GalleryCoverSourceKind.imageRelation,
        relationPropertyId = propertyId;

  const GalleryCoverSource.weblinkRelationRepresentativeImage(int propertyId)
      : kind = GalleryCoverSourceKind.weblinkRelationRepresentativeImage,
        relationPropertyId = propertyId;

  final GalleryCoverSourceKind kind;
  final int? relationPropertyId;

  bool get isRelation =>
      kind == GalleryCoverSourceKind.imageRelation ||
      kind == GalleryCoverSourceKind.weblinkRelationRepresentativeImage;

  static GalleryCoverSource fromStorage(Object? value) {
    if (value is! Map) return const GalleryCoverSource.none();
    final kind = GalleryCoverSourceKind.fromStorage(value['kind']);
    if (kind == null) return const GalleryCoverSource.none();

    switch (kind) {
      case GalleryCoverSourceKind.none:
        return const GalleryCoverSource.none();
      case GalleryCoverSourceKind.directImage:
        return const GalleryCoverSource.directImage();
      case GalleryCoverSourceKind.imageRelation:
      case GalleryCoverSourceKind.weblinkRelationRepresentativeImage:
        final rawPropertyId = value['relationPropertyId'];
        final propertyId = rawPropertyId is int
            ? rawPropertyId
            : int.tryParse('$rawPropertyId');
        if (propertyId == null || propertyId <= 0) {
          return const GalleryCoverSource.none();
        }
        return kind == GalleryCoverSourceKind.imageRelation
            ? GalleryCoverSource.imageRelation(propertyId)
            : GalleryCoverSource.weblinkRelationRepresentativeImage(propertyId);
    }
  }

  Map<String, dynamic> toStorage() => <String, dynamic>{
        'kind': kind.storageValue,
        if (isRelation) 'relationPropertyId': relationPropertyId,
      };

  @override
  bool operator ==(Object other) =>
      other is GalleryCoverSource &&
      other.kind == kind &&
      other.relationPropertyId == relationPropertyId;

  @override
  int get hashCode => Object.hash(kind, relationPropertyId);
}

/// Persists Gallery presentation settings without creating additional layout
/// types or changing Object/Database collection semantics.
class DatabaseViewGalleryAdapter {
  const DatabaseViewGalleryAdapter();

  static const settingsKey = 'galleryMode';
  static const coverSourceSettingsKey = 'galleryCoverSource';

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

  GalleryCoverSource decodeCoverSource(DatabaseViewConfig view) =>
      GalleryCoverSource.fromStorage(view.settings[coverSourceSettingsKey]);

  DatabaseViewConfig encodeCoverSource(
    DatabaseViewConfig view, {
    required GalleryCoverSource source,
  }) {
    final settings = <String, dynamic>{...view.settings};
    settings[coverSourceSettingsKey] = source.toStorage();
    return view.copyWith(settings: settings);
  }
}
