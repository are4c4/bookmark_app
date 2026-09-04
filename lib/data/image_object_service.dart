import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import 'object_type_defaults_store.dart';
import 'system_object_store.dart';

class ImageObjectDefinition {
  const ImageObjectDefinition({
    required this.objectType,
    required this.fileProperty,
    required this.noteProperty,
    required this.sourceUrlProperty,
    required this.originalFilenameProperty,
    required this.contentTypeProperty,
    required this.pixelWidthProperty,
    required this.pixelHeightProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition fileProperty;
  final ObjectPropertyDefinition noteProperty;
  final ObjectPropertyDefinition sourceUrlProperty;
  final ObjectPropertyDefinition originalFilenameProperty;
  final ObjectPropertyDefinition contentTypeProperty;
  final ObjectPropertyDefinition pixelWidthProperty;
  final ObjectPropertyDefinition pixelHeightProperty;

  double? aspectRatioFor(AppObject object) {
    final width = object.values[pixelWidthProperty.id];
    final height = object.values[pixelHeightProperty.id];
    if (width is! num || height is! num || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }
}

/// Stable Object-lane facade for the existing system Image ObjectType.
///
/// `CoreObjectBridge` mirrors legacy photos into the same system key `image`.
/// Native managed assets intentionally omit `Legacy Photo ID`; their canonical
/// identity remains the Image Object id while source URL/file metadata supports
/// provenance and retry-safe reuse.
class ImageObjectService {
  ImageObjectService({
    required this.systemObjects,
    required this.defaultsStore,
  });

  static const String systemKey = 'image';

  final SystemObjectStore systemObjects;
  final ObjectTypeDefaultsStore defaultsStore;

  Future<ImageObjectDefinition> ensureDefinition(int workspaceId) async {
    var type = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
      name: '画像',
      icon: '🖼️',
    );
    final file = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'File',
      type: ObjectPropertyType.file,
      config: const <String, dynamic>{'system': true},
    );
    final note = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Note',
      type: ObjectPropertyType.text,
    );
    final sourceUrl = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Source URL',
      type: ObjectPropertyType.url,
    );
    final originalFilename = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Original filename',
      type: ObjectPropertyType.text,
    );
    final contentType = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Content type',
      type: ObjectPropertyType.text,
    );
    final pixelWidth = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Pixel width',
      type: ObjectPropertyType.number,
      config: const <String, dynamic>{'system': true},
    );
    final pixelHeight = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Pixel height',
      type: ObjectPropertyType.number,
      config: const <String, dynamic>{'system': true},
    );
    type = (await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;

    // Pixel dimensions are hidden system metadata for presentation geometry;
    // adding them must not rewrite a user's visible Image Property defaults.
    await _ensureDefaults(
      objectTypeId: type.id,
      fileProperty: file,
      noteProperty: note,
      sourceUrlProperty: sourceUrl,
      originalFilenameProperty: originalFilename,
      contentTypeProperty: contentType,
    );

    return ImageObjectDefinition(
      objectType: type,
      fileProperty: file,
      noteProperty: note,
      sourceUrlProperty: sourceUrl,
      originalFilenameProperty: originalFilename,
      contentTypeProperty: contentType,
      pixelWidthProperty: pixelWidth,
      pixelHeightProperty: pixelHeight,
    );
  }

  /// Finds or creates one native Image Object for an app-managed asset.
  ///
  /// [sourceUrl] is the preferred reuse key when present. Otherwise [filePath]
  /// is used. Existing non-empty metadata is preserved so retries or another
  /// Weblink cannot silently replace the managed file already owned by an Image.
  Future<AppObject> findOrCreateManaged({
    required int workspaceId,
    required String filePath,
    String? sourceUrl,
    String? title,
    String? originalFilename,
    String? contentType,
    int? pixelWidth,
    int? pixelHeight,
  }) async {
    final path = filePath.trim();
    if (path.isEmpty) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'Managed Image file path must not be empty.',
      );
    }
    final source = _validatedSourceUrl(sourceUrl);
    final width = _validatedDimension(pixelWidth, 'pixelWidth');
    final height = _validatedDimension(pixelHeight, 'pixelHeight');
    final definition = await ensureDefinition(workspaceId);
    final objects = await systemObjects.objectStore.listObjects(
      definition.objectType.id,
    );

    for (final object in objects) {
      final storedSource =
          '${object.values[definition.sourceUrlProperty.id] ?? ''}'.trim();
      final storedFile =
          '${object.values[definition.fileProperty.id] ?? ''}'.trim();
      final matches =
          source != null ? storedSource == source : storedFile == path;
      if (!matches) continue;
      await _setIfMissing(object, definition.fileProperty, path);
      await _setIfMissing(object, definition.sourceUrlProperty, source);
      await _setIfMissing(
        object,
        definition.originalFilenameProperty,
        originalFilename,
      );
      await _setIfMissing(object, definition.contentTypeProperty, contentType);
      await _setNumberIfMissing(object, definition.pixelWidthProperty, width);
      await _setNumberIfMissing(object, definition.pixelHeightProperty, height);
      return _reload(definition.objectType.id, object.id);
    }

    final objectId = await systemObjects.objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: _firstNonEmpty(<String?>[
            title,
            originalFilename,
            _fileName(path),
          ]) ??
          'Image',
    );
    final created = await _reload(definition.objectType.id, objectId);
    await _setIfMissing(created, definition.fileProperty, path);
    await _setIfMissing(created, definition.sourceUrlProperty, source);
    await _setIfMissing(
      created,
      definition.originalFilenameProperty,
      originalFilename,
    );
    await _setIfMissing(created, definition.contentTypeProperty, contentType);
    await _setNumberIfMissing(created, definition.pixelWidthProperty, width);
    await _setNumberIfMissing(created, definition.pixelHeightProperty, height);
    return _reload(definition.objectType.id, objectId);
  }

  Future<void> _ensureDefaults({
    required int objectTypeId,
    required ObjectPropertyDefinition fileProperty,
    required ObjectPropertyDefinition noteProperty,
    required ObjectPropertyDefinition sourceUrlProperty,
    required ObjectPropertyDefinition originalFilenameProperty,
    required ObjectPropertyDefinition contentTypeProperty,
  }) async {
    final desiredVisible = <int>[fileProperty.id, noteProperty.id];
    final legacyOrder = <int>[fileProperty.id, noteProperty.id];
    final desiredOrder = <int>[
      fileProperty.id,
      noteProperty.id,
      sourceUrlProperty.id,
      originalFilenameProperty.id,
      contentTypeProperty.id,
    ];
    final current = await defaultsStore.read(objectTypeId);
    if (current == null) {
      await defaultsStore.write(
        objectTypeId: objectTypeId,
        defaults: ObjectTypeDefaults(
          visiblePropertyIds: desiredVisible,
          propertyOrder: desiredOrder,
          openMode: ObjectOpenMode.sidePeek,
        ),
      );
      return;
    }

    // Upgrade only the exact old Image order. Visibility is intentionally kept
    // at File/Note and customized settings are never replaced implicitly.
    final upgradeOrder = current.propertyOrder == null ||
        _sameIds(current.propertyOrder!, legacyOrder);
    if (!upgradeOrder && current.openMode != null) return;
    await defaultsStore.write(
      objectTypeId: objectTypeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: current.visiblePropertyIds ?? desiredVisible,
        propertyOrder: upgradeOrder ? desiredOrder : current.propertyOrder,
        openMode: current.openMode ?? ObjectOpenMode.sidePeek,
      ),
    );
  }

  bool _sameIds(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  String? _validatedSourceUrl(String? value) {
    final candidate = value?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError.value(
        value,
        'sourceUrl',
        'Image source URL must be absolute.',
      );
    }
    return uri.toString();
  }

  int? _validatedDimension(int? value, String name) {
    if (value == null) return null;
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'Image dimensions must be positive.');
    }
    return value;
  }

  Future<void> _setIfMissing(
    AppObject object,
    ObjectPropertyDefinition property,
    String? value,
  ) async {
    final candidate = value?.trim();
    if (candidate == null || candidate.isEmpty) return;
    final current = '${object.values[property.id] ?? ''}'.trim();
    if (current.isNotEmpty) return;
    await systemObjects.objectStore.setPropertyValue(
      objectId: object.id,
      property: property,
      value: candidate,
    );
  }

  Future<void> _setNumberIfMissing(
    AppObject object,
    ObjectPropertyDefinition property,
    int? value,
  ) async {
    if (value == null || object.values[property.id] != null) return;
    await systemObjects.objectStore.setPropertyValue(
      objectId: object.id,
      property: property,
      value: value,
    );
  }

  Future<AppObject> _reload(int objectTypeId, int objectId) async {
    final objects = await systemObjects.objectStore.listObjects(objectTypeId);
    for (final object in objects) {
      if (object.id == objectId) return object;
    }
    throw StateError('Image Object $objectId does not exist.');
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final candidate = value?.trim();
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }
}
