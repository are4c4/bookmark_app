import '../domain/managed_file_ownership.dart';
import '../domain/mime_type_normalizer.dart';
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
    required this.storageOwnershipProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition fileProperty;
  final ObjectPropertyDefinition noteProperty;
  final ObjectPropertyDefinition sourceUrlProperty;
  final ObjectPropertyDefinition originalFilenameProperty;
  final ObjectPropertyDefinition contentTypeProperty;
  final ObjectPropertyDefinition pixelWidthProperty;
  final ObjectPropertyDefinition pixelHeightProperty;
  final ObjectPropertyDefinition storageOwnershipProperty;

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
    final storageOwnership = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Storage ownership',
      type: ObjectPropertyType.text,
      config: const <String, dynamic>{'system': true},
    );
    type = (await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;

    // Pixel dimensions and storage ownership are hidden native metadata. Adding
    // them must not rewrite a user's visible Image Property defaults.
    await _ensureDefaults(
      objectTypeId: type.id,
      fileProperty: file,
      noteProperty: note,
      sourceUrlProperty: sourceUrl,
      originalFilenameProperty: originalFilename,
      contentTypeProperty: contentType,
      storageOwnershipProperty: storageOwnership,
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
      storageOwnershipProperty: storageOwnership,
    );
  }

  /// Looks up an existing Image through the same canonical source-URL identity
  /// rules used by [findOrCreateManaged].
  ///
  /// Older stored provenance may not already be normalized. Lookup normalizes
  /// both sides so callers can avoid expensive downloads/copies before the
  /// eventual create-or-reuse step without maintaining a second identity rule.
  Future<AppObject?> findBySourceUrl({
    required int workspaceId,
    required String sourceUrl,
  }) async {
    final source = _validatedSourceUrl(sourceUrl);
    if (source == null) return null;
    final definition = await ensureDefinition(workspaceId);
    final objects = await systemObjects.objectStore.listObjects(
      definition.objectType.id,
    );
    for (final object in objects) {
      final storedSource =
          '${object.values[definition.sourceUrlProperty.id] ?? ''}'.trim();
      if (_sourceUrlsMatch(storedSource, source)) return object;
    }
    return null;
  }

  /// Finds or creates one native Image Object for an app-managed asset.
  ///
  /// [sourceUrl] is the preferred reuse key when present, while canonical
  /// managed [filePath] remains a stable fallback identity so one stored asset
  /// cannot fan out into duplicate Image Objects when provenance changes.
  /// Paths inside the active profile/Vault are stored profile-relative using
  /// the same resolver contract as canonical File Objects; external paths stay
  /// absolute. Older absolute/relative representations of the same managed
  /// path therefore compare as one Image identity without changing Image's
  /// concrete ObjectType identity.
  /// Safe URL-equivalent source variants reuse one Image while query and
  /// fragment distinctions remain identity-significant across different files.
  /// Existing non-empty metadata is preserved so retries or another Weblink
  /// cannot silently replace the managed file or provenance already owned by
  /// an Image. Physical-byte ownership is persisted only when a trusted caller
  /// supplies the closed [ManagedFileOwnership] value; path location alone never
  /// manufactures ownership.
  Future<AppObject> findOrCreateManaged({
    required int workspaceId,
    required String filePath,
    String? sourceUrl,
    String? title,
    String? originalFilename,
    String? contentType,
    int? pixelWidth,
    int? pixelHeight,
    ManagedFileOwnership? storageOwnership,
  }) async {
    final path = _canonicalStoredPath(filePath);
    final source = _validatedSourceUrl(sourceUrl);
    final normalizedContentType = MimeTypeNormalizer.normalize(contentType);
    final width = _validatedDimension(pixelWidth, 'pixelWidth');
    final height = _validatedDimension(pixelHeight, 'pixelHeight');
    final ownershipStorageKey = storageOwnership?.storageKey;
    final definition = await ensureDefinition(workspaceId);
    final objects = await systemObjects.objectStore.listObjects(
      definition.objectType.id,
    );

    for (final object in objects) {
      final storedSource =
          '${object.values[definition.sourceUrlProperty.id] ?? ''}'.trim();
      final storedFile =
          '${object.values[definition.fileProperty.id] ?? ''}'.trim();
      final matchesSource =
          source != null && _sourceUrlsMatch(storedSource, source);
      final matchesFile = _storedPathsMatch(storedFile, path);
      if (!matchesSource && !matchesFile) continue;
      if (ownershipStorageKey != null &&
          matchesSource &&
          !matchesFile &&
          storedFile.isNotEmpty) {
        throw StateError(
          'Managed Image ownership cannot target a different stored file.',
        );
      }
      await _setIfMissing(object, definition.fileProperty, path);
      await _setIfMissing(object, definition.sourceUrlProperty, source);
      await _setIfMissing(
        object,
        definition.originalFilenameProperty,
        originalFilename,
      );
      await _setIfMissing(
        object,
        definition.contentTypeProperty,
        normalizedContentType,
      );
      await _setNumberIfMissing(object, definition.pixelWidthProperty, width);
      await _setNumberIfMissing(object, definition.pixelHeightProperty, height);
      await _setIfMissing(
        object,
        definition.storageOwnershipProperty,
        ownershipStorageKey,
      );
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
    await _setIfMissing(
      created,
      definition.contentTypeProperty,
      normalizedContentType,
    );
    await _setNumberIfMissing(created, definition.pixelWidthProperty, width);
    await _setNumberIfMissing(created, definition.pixelHeightProperty, height);
    await _setIfMissing(
      created,
      definition.storageOwnershipProperty,
      ownershipStorageKey,
    );
    return _reload(definition.objectType.id, objectId);
  }

  /// Replaces persisted layout geometry after the managed image bytes change.
  ///
  /// This deliberately updates only hidden pixel metadata. Image identity,
  /// managed File, title and provenance remain untouched so an editor can
  /// refresh Gallery/detail geometry without creating or retargeting an Image.
  Future<AppObject> updateManagedGeometry({
    required int workspaceId,
    required int objectId,
    required int pixelWidth,
    required int pixelHeight,
  }) async {
    final width = _validatedDimension(pixelWidth, 'pixelWidth')!;
    final height = _validatedDimension(pixelHeight, 'pixelHeight')!;
    final definition = await ensureDefinition(workspaceId);
    await _reload(definition.objectType.id, objectId);
    await systemObjects.objectStore.setPropertyValue(
      objectId: objectId,
      property: definition.pixelWidthProperty,
      value: width,
    );
    await systemObjects.objectStore.setPropertyValue(
      objectId: objectId,
      property: definition.pixelHeightProperty,
      value: height,
    );
    return _reload(definition.objectType.id, objectId);
  }

  Future<void> _ensureDefaults({
    required int objectTypeId,
    required ObjectPropertyDefinition fileProperty,
    required ObjectPropertyDefinition noteProperty,
    required ObjectPropertyDefinition sourceUrlProperty,
    required ObjectPropertyDefinition originalFilenameProperty,
    required ObjectPropertyDefinition contentTypeProperty,
    required ObjectPropertyDefinition storageOwnershipProperty,
  }) async {
    final desiredVisible = <int>[
      originalFilenameProperty.id,
      noteProperty.id,
      contentTypeProperty.id,
      sourceUrlProperty.id,
    ];
    final legacyVisible = <int>[fileProperty.id, noteProperty.id];
    final legacyOrder = <int>[fileProperty.id, noteProperty.id];
    final previousOrder = <int>[
      fileProperty.id,
      noteProperty.id,
      sourceUrlProperty.id,
      originalFilenameProperty.id,
      contentTypeProperty.id,
    ];
    final preOwnershipOrder = <int>[
      originalFilenameProperty.id,
      noteProperty.id,
      contentTypeProperty.id,
      sourceUrlProperty.id,
      fileProperty.id,
    ];
    final desiredOrder = <int>[
      originalFilenameProperty.id,
      noteProperty.id,
      contentTypeProperty.id,
      sourceUrlProperty.id,
      storageOwnershipProperty.id,
      fileProperty.id,
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

    // Upgrade only defaults written by earlier Image definitions. Any user
    // customization is preserved, while internal managed metadata stays hidden
    // from the default daily-use presentation.
    final upgradeVisible = current.visiblePropertyIds == null ||
        _sameIds(current.visiblePropertyIds!, legacyVisible);
    final upgradeOrder = current.propertyOrder == null ||
        _sameIds(current.propertyOrder!, legacyOrder) ||
        _sameIds(current.propertyOrder!, previousOrder) ||
        _sameIds(current.propertyOrder!, preOwnershipOrder);
    final needsWrite =
        upgradeVisible || upgradeOrder || current.openMode == null;
    if (!needsWrite) return;
    await defaultsStore.write(
      objectTypeId: objectTypeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds:
            upgradeVisible ? desiredVisible : current.visiblePropertyIds,
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
    return _normalizeSourceUrl(candidate, originalValue: candidate);
  }

  bool _sourceUrlsMatch(String stored, String normalizedCandidate) {
    if (stored.isEmpty) return false;
    try {
      return _normalizeSourceUrl(stored, originalValue: stored) ==
          normalizedCandidate;
    } on ArgumentError {
      // Malformed pre-existing provenance should not block a valid managed
      // Image from being created or reused by unrelated source metadata.
      return false;
    }
  }

  String _normalizeSourceUrl(
    String candidate, {
    required String originalValue,
  }) {
    final parsed = Uri.tryParse(candidate);
    if (parsed == null || !parsed.hasScheme) {
      throw ArgumentError.value(
        originalValue,
        'sourceUrl',
        'Image source URL must be absolute.',
      );
    }

    final uri = parsed.normalizePath();
    final scheme = uri.scheme.toLowerCase();
    if (!uri.hasAuthority || uri.host.isEmpty) {
      return uri.replace(scheme: scheme).toString();
    }

    final host = uri.host.toLowerCase();
    final defaultPort = uri.hasPort &&
        ((scheme == 'http' && uri.port == 80) ||
            (scheme == 'https' && uri.port == 443));
    final authority = StringBuffer();
    if (uri.userInfo.isNotEmpty) {
      authority
        ..write(uri.userInfo)
        ..write('@');
    }
    if (host.contains(':')) {
      authority
        ..write('[')
        ..write(host)
        ..write(']');
    } else {
      authority.write(host);
    }
    if (uri.hasPort && !defaultPort) {
      authority
        ..write(':')
        ..write(uri.port);
    }

    final path = uri.path.isEmpty && (scheme == 'http' || scheme == 'https')
        ? '/'
        : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    return '$scheme://${authority.toString()}$path$query$fragment';
  }

  String _canonicalStoredPath(String path) {
    final candidate = path.trim();
    if (candidate.isEmpty) {
      throw ArgumentError.value(
        path,
        'filePath',
        'Managed Image file path must not be empty.',
      );
    }
    return systemObjects.database.pathResolver.canonicalStoredPath(candidate);
  }

  bool _storedPathsMatch(String stored, String canonicalCandidate) {
    if (stored.isEmpty) return false;
    try {
      return _canonicalStoredPath(stored) == canonicalCandidate;
    } on ArgumentError {
      return false;
    }
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
