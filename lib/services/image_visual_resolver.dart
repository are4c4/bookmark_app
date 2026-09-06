import 'dart:developer' as developer;
import 'dart:io';

import 'package:image/image.dart' as image;

import '../data/object_store.dart';
import '../data/profile_path_resolver.dart';
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
/// mutates Object values. Persisted Pixel width/height are preferred layout
/// metadata. If either persisted dimension is unavailable/invalid, the resolver
/// may probe the existing managed file read-only and use the decoded dimension
/// pair for this presentation result without writing metadata back to storage.
/// Profile-relative File values are resolved only at this read boundary so the
/// stored Image identity remains portable across profile/Vault moves.
class ImageVisualResolver {
  const ImageVisualResolver(
    this._objectStore, {
    ProfilePathResolver? pathResolver,
  }) : _pathResolver = pathResolver;

  final ObjectStore _objectStore;
  final ProfilePathResolver? _pathResolver;

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
    AppObject? imageObject;
    for (final candidate in objects) {
      if (candidate.id == imageObjectId) {
        imageObject = candidate;
        break;
      }
    }
    if (imageObject == null) return null;

    final storedPath =
        _nonEmpty(imageObject.values[fileProperties.single.id]?.toString());
    if (storedPath == null) return null;
    final path = _pathResolver?.resolveStoredPath(storedPath) ?? storedPath;
    if (!await _existingFile(path)) return null;

    var width = _dimensionValue(
      imageType.properties
          .where((property) => property.name == 'Pixel width')
          .toList(growable: false),
      imageObject.values,
    );
    var height = _dimensionValue(
      imageType.properties
          .where((property) => property.name == 'Pixel height')
          .toList(growable: false),
      imageObject.values,
    );
    if (width == null || height == null) {
      final probed = await _probeGeometry(path);
      if (probed != null) {
        // Use one coherent decoded pair rather than mixing persisted and probed
        // values. Partial persisted geometry may be stale after older edits.
        width = probed.width;
        height = probed.height;
      }
    }

    return ImageManagedVisual(
      imageObjectId: imageObject.id,
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

  Future<({int width, int height})?> _probeGeometry(String path) async {
    try {
      final decoded = image.decodeImage(await File(path).readAsBytes());
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return null;
      }
      return (width: decoded.width, height: decoded.height);
    } catch (_, stackTrace) {
      _debugGeometryProbeFailure(stackTrace);
      return null;
    }
  }

  Future<bool> _existingFile(String path) async {
    try {
      return await File(path).exists();
    } catch (_, stackTrace) {
      _debugFileProbeFailure(stackTrace);
      return false;
    }
  }

  void _debugGeometryProbeFailure(StackTrace stackTrace) {
    assert(() {
      developer.log(
        'ImageVisualResolver: managed image geometry probe failed; '
        'continuing without fallback dimensions.',
        name: 'bookmark_app.image_visual_resolver',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }

  void _debugFileProbeFailure(StackTrace stackTrace) {
    assert(() {
      developer.log(
        'ImageVisualResolver: managed file existence probe failed; '
        'treating the optional visual as unavailable.',
        name: 'bookmark_app.image_visual_resolver',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
