import 'package:file_selector/file_selector.dart';

import '../data/relation_target_quick_create_policy.dart';
import '../data/relation_target_quick_create_service.dart';
import 'generic_database_file_import_service.dart';
import 'generic_database_image_import_service.dart';
import 'primitive_file_import_classifier.dart';
import 'primitive_object_import_service.dart';

typedef RelationTargetSourceFilePicker = Future<String?> Function();

/// Presentation-host composition for Relation target quick-create.
///
/// Generic title/name/URL creation remains delegated to
/// [RelationTargetQuickCreateService]. Managed Image/File creation first opens a
/// single native file picker, then routes the selected source through the
/// canonical content-first primitive classifier and the existing managed import
/// services. The non-target primitive importer is deliberately fail-closed, so
/// selecting Image content for a File Relation (or vice versa) cannot create an
/// orphan Object before target validation rejects it.
class RelationTargetQuickCreateHostService {
  RelationTargetQuickCreateHostService({
    required this.policy,
    required this.quickCreate,
    required this.imageImport,
    required this.fileImport,
    RelationTargetSourceFilePicker? pickFile,
  }) : _pickFile = pickFile ?? _pickOneFile;

  final RelationTargetQuickCreatePolicy policy;
  final RelationTargetQuickCreateService quickCreate;
  final GenericDatabaseImageImportService imageImport;
  final GenericDatabaseFileImportService? fileImport;
  final RelationTargetSourceFilePicker _pickFile;

  Future<RelationTargetQuickCreateMode> modeFor({
    required int workspaceId,
    required int targetObjectTypeId,
  }) async {
    final mode = await policy.modeFor(
      workspaceId: workspaceId,
      targetObjectTypeId: targetObjectTypeId,
    );
    if (mode == RelationTargetQuickCreateMode.managedFile && fileImport == null) {
      return RelationTargetQuickCreateMode.unavailable;
    }
    return mode;
  }

  bool requiresInput(RelationTargetQuickCreateMode mode) => switch (mode) {
        RelationTargetQuickCreateMode.managedImage ||
        RelationTargetQuickCreateMode.managedFile => false,
        RelationTargetQuickCreateMode.genericObject ||
        RelationTargetQuickCreateMode.tag ||
        RelationTargetQuickCreateMode.weblinkUrl ||
        RelationTargetQuickCreateMode.unavailable => true,
      };

  String labelFor(RelationTargetQuickCreateMode mode, String rawInput) {
    final input = rawInput.trim();
    return switch (mode) {
      RelationTargetQuickCreateMode.genericObject =>
        input.isEmpty ? '新しいObjectを作成' : '「$input」を作成',
      RelationTargetQuickCreateMode.tag =>
        input.isEmpty ? '新しいタグを作成' : 'タグ「$input」を作成',
      RelationTargetQuickCreateMode.weblinkUrl => input.isEmpty
          ? 'URLからWeblinkを追加'
          : '「$input」をWeblinkとして追加',
      RelationTargetQuickCreateMode.managedImage => '画像をインポート',
      RelationTargetQuickCreateMode.managedFile => 'ファイルをインポート',
      RelationTargetQuickCreateMode.unavailable => 'Objectを作成',
    };
  }

  Future<int?> create({
    required int workspaceId,
    required int targetObjectTypeId,
    required RelationTargetQuickCreateMode mode,
    String? input,
  }) async {
    if (mode == RelationTargetQuickCreateMode.unavailable) {
      throw UnsupportedError(
        'This ObjectType does not support safe Relation target quick-create.',
      );
    }

    final object = await quickCreate.create(
      workspaceId: workspaceId,
      targetObjectTypeId: targetObjectTypeId,
      input: input,
      createManagedImage: mode == RelationTargetQuickCreateMode.managedImage
          ? () => _pickAndImport(
                targetObjectTypeId: targetObjectTypeId,
                expectedTarget: PrimitiveFileImportTarget.image,
              )
          : null,
      createManagedFile: mode == RelationTargetQuickCreateMode.managedFile
          ? () => _pickAndImport(
                targetObjectTypeId: targetObjectTypeId,
                expectedTarget: PrimitiveFileImportTarget.file,
              )
          : null,
    );
    return object?.id;
  }

  Future<int?> _pickAndImport({
    required int targetObjectTypeId,
    required PrimitiveFileImportTarget expectedTarget,
  }) async {
    final sourcePath = (await _pickFile())?.trim();
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final fileImporter = fileImport;

    final router = PrimitiveObjectImportService(
      importImage: ({
        required int databaseId,
        required String sourcePath,
        String? contentType,
      }) {
        if (expectedTarget != PrimitiveFileImportTarget.image) {
          throw StateError(
            'Selected content is an Image and cannot populate a File Relation.',
          );
        }
        final canonicalContentType = contentType?.trim();
        if (canonicalContentType == null || canonicalContentType.isEmpty) {
          throw StateError('Image import requires a canonical content type.');
        }
        return imageImport.importClassifiedPath(
          databaseId: databaseId,
          sourcePath: sourcePath,
          contentType: canonicalContentType,
        );
      },
      importFile: ({
        required int databaseId,
        required String sourcePath,
        String? contentType,
      }) {
        if (expectedTarget != PrimitiveFileImportTarget.file) {
          throw StateError(
            'Selected content is not a supported Image and cannot populate an Image Relation.',
          );
        }
        if (fileImporter == null) {
          throw StateError('Managed File import requires an active Vault path.');
        }
        return fileImporter.importClassifiedPath(
          databaseId: databaseId,
          sourcePath: sourcePath,
          contentType: contentType,
        );
      },
    );

    final result = await router.importPath(
      databaseId: targetObjectTypeId,
      sourcePath: sourcePath,
    );
    if (result.target != expectedTarget) {
      throw StateError('Managed Relation import resolved an unexpected primitive.');
    }
    return result.objectId;
  }
}

Future<String?> _pickOneFile() async => (await openFile())?.path;
