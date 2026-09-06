import '../data/object_store.dart';
import '../data/profile_path_resolver.dart';
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

/// Resolves the file-backed capability of one canonical File Object read-only.
///
/// The caller is responsible for verifying [fileObjectTypeId] is the canonical
/// system File ObjectType. Object identity/metadata stay in FileObjectService;
/// portable path resolution and filesystem probing are delegated to the same
/// [ManagedFileResolver] used by Image presentation.
class FileManagedResourceResolver {
  const FileManagedResourceResolver(
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
