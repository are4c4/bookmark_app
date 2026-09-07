import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import 'object_type_defaults_store.dart';
import 'system_object_store.dart';

class FileObjectDefinition {
  const FileObjectDefinition({
    required this.objectType,
    required this.fileProperty,
    required this.originalFilenameProperty,
    required this.contentTypeProperty,
    required this.extensionProperty,
    required this.sizeBytesProperty,
    required this.importedAtProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition fileProperty;
  final ObjectPropertyDefinition originalFilenameProperty;
  final ObjectPropertyDefinition contentTypeProperty;
  final ObjectPropertyDefinition extensionProperty;
  final ObjectPropertyDefinition sizeBytesProperty;
  final ObjectPropertyDefinition importedAtProperty;
}

/// Canonical generic File primitive.
///
/// File identity belongs to this ObjectType while filesystem lifecycle remains
/// outside it. Managed paths are stored profile-relative whenever the active
/// [AppDatabase] profile root can relativize them, keeping identity compatible
/// with future Vault moves without introducing a second file persistence model.
class FileObjectService {
  FileObjectService({
    required this.systemObjects,
    required this.defaultsStore,
  });

  static const String systemKey = 'file';

  final SystemObjectStore systemObjects;
  final ObjectTypeDefaultsStore defaultsStore;

  Future<FileObjectDefinition> ensureDefinition(int workspaceId) async {
    var type = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
      name: 'File',
      icon: '📄',
    );
    final file = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'File',
      type: ObjectPropertyType.file,
      config: const <String, dynamic>{'system': true},
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
    final extension = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Extension',
      type: ObjectPropertyType.text,
    );
    final sizeBytes = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Size bytes',
      type: ObjectPropertyType.number,
      config: const <String, dynamic>{'system': true},
    );
    final importedAt = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Imported at',
      type: ObjectPropertyType.date,
      config: const <String, dynamic>{'system': true},
    );
    type = (await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;

    await _ensureDefaults(
      objectTypeId: type.id,
      fileProperty: file,
      originalFilenameProperty: originalFilename,
      contentTypeProperty: contentType,
      extensionProperty: extension,
      sizeBytesProperty: sizeBytes,
      importedAtProperty: importedAt,
    );

    return FileObjectDefinition(
      objectType: type,
      fileProperty: file,
      originalFilenameProperty: originalFilename,
      contentTypeProperty: contentType,
      extensionProperty: extension,
      sizeBytesProperty: sizeBytes,
      importedAtProperty: importedAt,
    );
  }

  /// Creates or reuses one File Object for one managed stored-path identity.
  ///
  /// Reimport is deterministic by canonical stored path. Existing non-empty
  /// metadata is preserved; a retry may only fill fields that were previously
  /// missing. Hash-based dedup can be added later without changing this path
  /// identity contract.
  Future<AppObject> findOrCreateManaged({
    required int workspaceId,
    required String filePath,
    String? title,
    String? originalFilename,
    String? contentType,
    int? sizeBytes,
    DateTime? importedAt,
  }) async {
    final storedPath = _canonicalStoredPath(filePath);
    final validatedSize = _validatedSize(sizeBytes);
    final filename = _firstNonEmpty(<String?>[
      originalFilename,
      _fileName(storedPath),
    ]);
    final normalizedContentType = _normalizedContentType(contentType);
    final extension = _extension(filename ?? storedPath);
    final importedAtValue =
        (importedAt ?? DateTime.now()).toUtc().toIso8601String();
    final definition = await ensureDefinition(workspaceId);
    final objects = await systemObjects.objectStore.listObjects(
      definition.objectType.id,
    );

    for (final object in objects) {
      final existingPath =
          '${object.values[definition.fileProperty.id] ?? ''}'.trim();
      if (existingPath.isEmpty ||
          _canonicalStoredPath(existingPath) != storedPath) {
        continue;
      }
      await _setIfMissing(
        object,
        definition.originalFilenameProperty,
        filename,
      );
      await _setIfMissing(
        object,
        definition.contentTypeProperty,
        normalizedContentType,
      );
      await _setIfMissing(object, definition.extensionProperty, extension);
      await _setNumberIfMissing(
        object,
        definition.sizeBytesProperty,
        validatedSize,
      );
      await _setIfMissing(
        object,
        definition.importedAtProperty,
        importedAtValue,
      );
      return _reload(definition.objectType.id, object.id);
    }

    final objectId = await systemObjects.objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: _firstNonEmpty(<String?>[
            title,
            filename,
            _fileName(storedPath),
          ]) ??
          'File',
    );
    final created = await _reload(definition.objectType.id, objectId);
    await _setIfMissing(created, definition.fileProperty, storedPath);
    await _setIfMissing(
      created,
      definition.originalFilenameProperty,
      filename,
    );
    await _setIfMissing(
      created,
      definition.contentTypeProperty,
      normalizedContentType,
    );
    await _setIfMissing(created, definition.extensionProperty, extension);
    await _setNumberIfMissing(
      created,
      definition.sizeBytesProperty,
      validatedSize,
    );
    await _setIfMissing(
      created,
      definition.importedAtProperty,
      importedAtValue,
    );
    return _reload(definition.objectType.id, objectId);
  }

  Future<void> _ensureDefaults({
    required int objectTypeId,
    required ObjectPropertyDefinition fileProperty,
    required ObjectPropertyDefinition originalFilenameProperty,
    required ObjectPropertyDefinition contentTypeProperty,
    required ObjectPropertyDefinition extensionProperty,
    required ObjectPropertyDefinition sizeBytesProperty,
    required ObjectPropertyDefinition importedAtProperty,
  }) async {
    final desiredVisible = <int>[
      originalFilenameProperty.id,
      contentTypeProperty.id,
      extensionProperty.id,
      sizeBytesProperty.id,
      importedAtProperty.id,
    ];
    final desiredOrder = <int>[
      originalFilenameProperty.id,
      contentTypeProperty.id,
      extensionProperty.id,
      sizeBytesProperty.id,
      importedAtProperty.id,
      fileProperty.id,
    ];
    final current = await defaultsStore.read(objectTypeId);
    if (current != null) return;
    await defaultsStore.write(
      objectTypeId: objectTypeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: desiredVisible,
        propertyOrder: desiredOrder,
        openMode: ObjectOpenMode.sidePeek,
      ),
    );
  }

  String _canonicalStoredPath(String path) {
    final candidate = path.trim();
    if (candidate.isEmpty) {
      throw ArgumentError.value(
        path,
        'filePath',
        'Managed File path must not be empty.',
      );
    }
    return systemObjects.database.pathResolver.canonicalStoredPath(candidate);
  }

  int? _validatedSize(int? value) {
    if (value == null) return null;
    if (value < 0) {
      throw ArgumentError.value(
        value,
        'sizeBytes',
        'Managed File size must not be negative.',
      );
    }
    return value;
  }

  String? _normalizedContentType(String? value) {
    final candidate = value?.trim().toLowerCase();
    if (candidate == null || candidate.isEmpty) return null;
    final separator = candidate.indexOf(';');
    final mime = separator < 0
        ? candidate
        : candidate.substring(0, separator).trim();
    return mime.isEmpty ? null : mime;
  }

  String? _extension(String path) {
    final name = _fileName(path);
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
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
    throw StateError('File Object $objectId does not exist.');
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
