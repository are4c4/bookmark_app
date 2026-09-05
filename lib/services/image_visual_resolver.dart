import 'dart:io';

import '../data/object_store.dart';
import '../domain/object_model.dart';

class ImageManagedVisual {
  const ImageManagedVisual({
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

/// Resolves one managed Image Object for presentation only.
///
/// The caller is responsible for verifying that [imageObjectTypeId] is the
/// canonical system Image ObjectType. This reader never ensures schema or
/// mutates Object values. Persisted Pixel width/height remain optional layout
/// metadata, while the managed file must still exist before it is presented.
class ImageVisualResolver {
  const ImageVisualResolver(this._objectStore);

  final ObjectStore _objectStore;

  Future<ImageManagedVisual?> resolveManaged({
    required int imageObjectTypeId,
    required int imageObjectId,
  }) async {
    if (imageObjectTypeId <= 0 || imageObjectId <= 0) return null;

    final imageType = await _objectStore.getObjectType(imageObjectTypeId);
    if (imageType == null) return null;
    final fileProperties = imageType.properties
        .where((property) => property.name == 'File')
        .toList(growable: false);
    if (fileProperties.length != 1) return null;

    final objects = await _objectStore.listObjects(imageObjectTypeId);
    AppObject? image;
    for (final candidate in objects) {
      if (candidate.id == imageObjectId) {
        image = candidate;
        break;
      }
    }
    if (image == null) return null;

    final path = _nonEmpty(image.values[fileProperties.single.id]?.toString());
    if (path == null || !await _existingFile(path)) return null;

    final width = _dimensionValue(
      imageType.properties
          .where((property) => property.name == 'Pixel width')
          .toList(growable: false),
      image.values,
    );
    final height = _dimensionValue(
      imageType.properties
          .where((property) => property.name == 'Pixel height')
          .toList(growable: false),
      image.values,
    );

    return ImageManagedVisual(
      imageObjectId: image.id,
      filePath: path,
      pixelWidth: width,
      pixelHeight: height,
    );
  }

  int? _dimensionValue(
    List<ObjectPropertyDefinition> properties,
    Map<int, dynamic> values,
  ) {
    if (properties.length != 1) return null;
    final value = values[properties.single.id];
    if (value is! num || !value.isFinite || value <= 0) return null;
    final integer = value.toInt();
    if (integer.toDouble() != value.toDouble()) return null;
    return integer;
  }

  Future<bool> _existingFile(String path) async {
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
