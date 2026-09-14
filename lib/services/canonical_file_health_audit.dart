import '../data/file_object_service.dart';
import '../data/object_store.dart';
import '../data/profile_path_resolver.dart';
import '../data/system_object_store.dart';
import '../domain/managed_file_ownership.dart';
import '../domain/object_model.dart';
import 'managed_file_resolver.dart';

enum CanonicalFileHealthIssueKind {
  missingFileReference,
  missingBytes,
  persistedSizeMismatch,
  unsupportedOwnership,
}

class CanonicalFileHealthFinding {
  const CanonicalFileHealthFinding({
    required this.fileObjectId,
    required this.kind,
  });

  final int fileObjectId;
  final CanonicalFileHealthIssueKind kind;
}

class CanonicalFileHealthAuditResult {
  const CanonicalFileHealthAuditResult({required this.findings});

  final List<CanonicalFileHealthFinding> findings;

  int get issueCount => findings.length;

  Set<int> get affectedFileObjectIds =>
      findings.map((finding) => finding.fileObjectId).toSet();
}

/// Read-only health audit for the registered canonical File ObjectType.
///
/// Findings expose only internal File Object ids plus stable issue kinds. The
/// audit never repairs metadata, rewrites paths, hashes content, or manufactures
/// managed-byte ownership from path location.
class CanonicalFileHealthAudit {
  CanonicalFileHealthAudit({
    required ObjectStore objectStore,
    required SystemObjectStore systemObjects,
    ProfilePathResolver? pathResolver,
  }) : _objectStore = objectStore,
       _systemObjects = systemObjects,
       _fileResolver = ManagedFileResolver(pathResolver: pathResolver);

  final ObjectStore _objectStore;
  final SystemObjectStore _systemObjects;
  final ManagedFileResolver _fileResolver;

  Future<CanonicalFileHealthAuditResult> run({required int workspaceId}) async {
    if (workspaceId <= 0) return _emptyResult;

    final type = await _systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: FileObjectService.systemKey,
    );
    if (type == null) return _emptyResult;

    final fileProperty = _uniqueProperty(type, 'File');
    if (fileProperty == null || fileProperty.type != ObjectPropertyType.file) {
      return _emptyResult;
    }

    final findings = <CanonicalFileHealthFinding>[];
    final objects = await _objectStore.listObjects(type.id);
    for (final object in objects) {
      final storedPath = _stringValue(object.values[fileProperty.id]);
      if (storedPath == null) {
        findings.add(
          CanonicalFileHealthFinding(
            fileObjectId: object.id,
            kind: CanonicalFileHealthIssueKind.missingFileReference,
          ),
        );
        continue;
      }

      final ownership = _valueFor(type, object, 'Storage ownership');
      if (ownership != null &&
          ManagedFileOwnership.fromStorageKey(ownership) == null) {
        findings.add(
          CanonicalFileHealthFinding(
            fileObjectId: object.id,
            kind: CanonicalFileHealthIssueKind.unsupportedOwnership,
          ),
        );
      }

      final reference = await _fileResolver.resolveExisting(storedPath);
      if (reference == null) {
        findings.add(
          CanonicalFileHealthFinding(
            fileObjectId: object.id,
            kind: CanonicalFileHealthIssueKind.missingBytes,
          ),
        );
        continue;
      }

      final persistedSize = _integerValueFor(type, object, 'Size bytes');
      if (persistedSize != null && persistedSize != reference.sizeBytes) {
        findings.add(
          CanonicalFileHealthFinding(
            fileObjectId: object.id,
            kind: CanonicalFileHealthIssueKind.persistedSizeMismatch,
          ),
        );
      }
    }

    return CanonicalFileHealthAuditResult(
      findings: List<CanonicalFileHealthFinding>.unmodifiable(findings),
    );
  }

  static const _emptyResult = CanonicalFileHealthAuditResult(
    findings: <CanonicalFileHealthFinding>[],
  );

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
