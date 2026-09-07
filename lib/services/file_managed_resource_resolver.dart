import '../data/file_object_service.dart';
import '../data/object_store.dart';
import '../data/profile_path_resolver.dart';
import '../data/system_object_store.dart';
import '../domain/object_model.dart';
import 'managed_file_resolver.dart';

class FileManagedResource {
  const FileManagedResource({
    required this.fileObjectId,
    required this.filePath,
    required this.actualSizeBytes,
    required this.modifiedAt,
    this.originalFilename,
    this.contentType,
    this.extension,
    this.persistedSizeBytes,
  });

  final int fileObjectId;
  final String filePath;
  final String? originalFilename;
  final String? contentType;
  final String? extension;
  final int? persistedSizeBytes;
  final int actualSizeBytes;
  final DateTime modifiedAt;
}

/// Low-level read-only resolver for a File-shaped ObjectType.
///
/// This class deliberately does not infer built-in primitive identity from
/// Property names. Production native File/PDF capability composition should use
/// [CanonicalFileManagedResourceResolver], which first verifies the registered
/// system File ObjectType. Portable path resolution and filesystem probing are
/// delegated to the shared [ManagedFileResolver].
class FileManagedResourceResolver {
  FileManagedResourceResolver(
    this._objectStore, {
    ProfilePathResolver? pathResolver,
  }) : _fileResolver = ManagedFileResolver(pathResolver: pathResolver);

  final ObjectStore _objectStore;
  final ManagedFileResolver _fileResolver;

  Future<FileManagedResource?> resolveManaged({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    if (fileObjectTypeId <= 0 || fileObjectId <= 0) return null;
    final type = await _objectStore.getObjectType(fileObjectTypeId);
    if (type == null) return null;

    final fileProperty = _uniqueProperty(type, 'File');
    if (fileProperty == null || fileProperty.type != ObjectPropertyType.file) {
      return null;
    }
    final objects = await _objectStore.listObjects(fileObjectTypeId);
    AppObject? object;
    for (final candidate in objects) {
      if (candidate.id == fileObjectId) {
        object = candidate;
        break;
      }
    }
    if (object == null) return null;

    final storedPath = _stringValue(object.values[fileProperty.id]);
    final reference = await _fileResolver.resolveExisting(storedPath);
    if (reference == null) return null;

    final originalFilename = _valueFor(type, object, 'Original filename');
    final contentType = _valueFor(type, object, 'Content type');
    final extension = _valueFor(type, object, 'Extension');
    final persistedSize = _integerValueFor(type, object, 'Size bytes');

    return FileManagedResource(
      fileObjectId: object.id,
      filePath: reference.resolvedPath,
      originalFilename: originalFilename,
      contentType: contentType,
      extension: extension,
      persistedSizeBytes: persistedSize,
      actualSizeBytes: reference.sizeBytes,
      modifiedAt: reference.modifiedAt,
    );
  }

  ObjectPropertyDefinition? _uniqueProperty(AppObjectType type, String name) {
    final matches = type.properties
        .where((property) => property.name == name)
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  String? _valueFor(AppObjectType type, AppObject object, String name) {
    final property = _uniqueProperty(type, name);
    return property == null ? null : _stringValue(object.values[property.id]);
  }

  int? _integerValueFor(AppObjectType type, AppObject object, String name) {
    final property = _uniqueProperty(type, name);
    if (property == null) return null;
    final value = object.values[property.id];
    if (value is! num || !value.isFinite || value < 0) return null;
    final integer = value.toInt();
    return integer.toDouble() == value.toDouble() ? integer : null;
  }

  String? _stringValue(dynamic value) {
    final candidate = value?.toString().trim();
    return candidate == null || candidate.isEmpty ? null : candidate;
  }
}

/// Native file-backed resolver that refuses to activate File/PDF capability for
/// arbitrary custom ObjectTypes that merely happen to contain a `File`
/// Property.
///
/// Built-in identity is verified through the system ObjectType registry before
/// any path or filesystem probe runs. This keeps PDF preview/metadata/text and
/// other native File behavior attached to the concrete canonical File primitive
/// rather than becoming implicit structural inheritance.
class CanonicalFileManagedResourceResolver extends FileManagedResourceResolver {
  CanonicalFileManagedResourceResolver({
    required ObjectStore objectStore,
    required SystemObjectStore systemObjects,
    ProfilePathResolver? pathResolver,
  })  : _systemObjects = systemObjects,
        super(objectStore, pathResolver: pathResolver);

  final SystemObjectStore _systemObjects;

  @override
  Future<FileManagedResource?> resolveManaged({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    if (fileObjectTypeId <= 0 || fileObjectId <= 0) return null;
    final systemKey = await _systemObjects.systemKeyForObjectType(
      fileObjectTypeId,
    );
    if (systemKey != FileObjectService.systemKey) return null;
    return super.resolveManaged(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
  }
}
