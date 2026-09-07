import '../data/object_store.dart';
import '../data/profile_path_resolver.dart';
import '../data/relation_read_service.dart';
import '../data/weblink_image_schema_service.dart';
import 'image_visual_resolver.dart';

class WeblinkManagedVisual {
  const WeblinkManagedVisual({
    required this.imageObjectId,
    required this.filePath,
    this.pixelWidth,
    this.pixelHeight,
  });

  final int imageObjectId;
  final String filePath;
  final int? pixelWidth;
  final int? pixelHeight;

  double? get aspectRatio {
    final width = pixelWidth;
    final height = pixelHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }
}

/// Resolves a Weblink's managed Representative Image for presentation only.
///
/// This reader deliberately consumes the canonical Relation index through
/// [RelationReadService]. It never ensures schema, mutates Relation state, or
/// tries to repair ambiguous/missing data. Generic Weblink detail/Gallery hosts
/// and legacy Bookmark presentation can therefore share one fail-closed path.
/// Managed Image path/existence/geometry reads delegate to [ImageVisualResolver]
/// so Weblink presentation does not maintain a parallel file-backed capability.
/// Geometry probing is disabled here to preserve the persisted-metadata-only
/// behavior of Weblink cards while still resolving profile-relative Image File
/// values at the read boundary.
class WeblinkVisualResolver {
  WeblinkVisualResolver(
    ObjectStore objectStore, {
    ProfilePathResolver? pathResolver,
  })  : _imageVisuals = ImageVisualResolver(
          objectStore,
          pathResolver: pathResolver,
          probeMissingGeometry: false,
        ),
        _relationReads = RelationReadService(objectStore);

  final ImageVisualResolver _imageVisuals;
  final RelationReadService _relationReads;

  Future<WeblinkManagedVisual?> resolveManagedRepresentative({
    required int weblinkObjectTypeId,
    required int weblinkObjectId,
  }) async {
    if (weblinkObjectTypeId <= 0 || weblinkObjectId <= 0) return null;

    final outgoing = await _relationReads.outgoing(
      sourceObjectTypeId: weblinkObjectTypeId,
      sourceObjectId: weblinkObjectId,
    );
    final representatives = outgoing
        .where(
          (entry) =>
              entry.property.name ==
                  WeblinkImageSchemaService.representativeImageName &&
              !entry.property.allowsMultipleRelations &&
              entry.property.targetObjectTypeId != null,
        )
        .toList(growable: false);
    if (representatives.length != 1) return null;

    final representative = representatives.single;
    final imageTypeId = representative.property.targetObjectTypeId!;
    if (representative.targetObject.objectTypeId != imageTypeId) return null;

    final visual = await _imageVisuals.resolveManaged(
      imageObjectTypeId: imageTypeId,
      imageObjectId: representative.targetObject.id,
    );
    if (visual == null) return null;

    return WeblinkManagedVisual(
      imageObjectId: visual.imageObjectId,
      filePath: visual.filePath,
      pixelWidth: visual.pixelWidth,
      pixelHeight: visual.pixelHeight,
    );
  }
}
