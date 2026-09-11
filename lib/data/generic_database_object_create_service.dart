import 'dart:developer' as developer;

import '../domain/managed_file_ownership.dart';
import '../domain/object_group.dart';
import '../domain/object_model.dart';
import 'canonical_object_mutation_impact_sink.dart';
import 'canonical_weblink_capture_service.dart';
import 'daily_note_service.dart';
import 'file_object_service.dart';
import 'generic_database_collection_page_data.dart';
import 'image_object_service.dart';
import 'object_board_create_service.dart';
import 'object_store.dart';
import 'person_object_bridge.dart';
import 'person_object_write_service.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';

typedef GenericDatabaseWeblinkCreateEnricher = Future<void> Function({
  required int workspaceId,
  required int objectId,
  required String url,
});

enum GenericDatabaseCreateMode {
  generic,
  dailyNote,
  weblinkUrl,
  managedImage,
  managedFile,
}

/// Object creation facade for collection-backed Database pages.
///
/// Database identity and ObjectType identity may differ. This service always
/// resolves the current Database collection first so new Objects are created in
/// the configured target ObjectType instead of assuming `databaseId` is also an
/// ObjectType id.
class GenericDatabaseObjectCreateService {
  const GenericDatabaseObjectCreateService({
    required this.pageLoader,
    required this.objectStore,
    required this.boardCreate,
    this.systemObjects,
    this.dailyNotes,
    this.weblinks,
    this.images,
    this.files,
    this.weblinkCreateEnricher,
    this.canonicalObjectMutationImpactSink,
  });

  final GenericDatabaseCollectionPageLoader pageLoader;
  final ObjectStore objectStore;
  final ObjectBoardCreateService boardCreate;
  final SystemObjectStore? systemObjects;
  final DailyNoteService? dailyNotes;
  final WeblinkObjectService? weblinks;
  final ImageObjectService? images;
  final FileObjectService? files;
  final GenericDatabaseWeblinkCreateEnricher? weblinkCreateEnricher;
  final CanonicalObjectMutationImpactSink? canonicalObjectMutationImpactSink;

  /// Returns the user-facing creation mode for an ObjectType.
  ///
  /// Native primitive modes are granted only from the registered system key;
  /// custom ObjectTypes that merely contain similarly typed Properties remain
  /// generic.
  Future<GenericDatabaseCreateMode> createModeForObjectType(
    int objectTypeId,
  ) async {
    final registry = systemObjects;
    if (registry == null) return GenericDatabaseCreateMode.generic;
    final systemKey = await registry.systemKeyForObjectType(objectTypeId);
    return switch (systemKey) {
      DailyNoteService.systemKey => GenericDatabaseCreateMode.dailyNote,
      WeblinkObjectService.systemKey => GenericDatabaseCreateMode.weblinkUrl,
      ImageObjectService.systemKey => GenericDatabaseCreateMode.managedImage,
      FileObjectService.systemKey => GenericDatabaseCreateMode.managedFile,
      _ => GenericDatabaseCreateMode.generic,
    };
  }

  /// Backward-compatible capability query for hosts that have not yet consumed
  /// [GenericDatabaseCreateMode.managedFile].
  Future<bool> requiresManagedFileImport(int objectTypeId) async {
    if (objectTypeId <= 0) return false;
    return await createModeForObjectType(objectTypeId) ==
        GenericDatabaseCreateMode.managedFile;
  }

  Future<int> create({
    required int databaseId,
    required String title,
  }) async {
    final page = await _load(databaseId);
    final systemKey = await _systemKey(page);
    if (systemKey == DailyNoteService.systemKey) {
      final service = dailyNotes;
      if (service == null) {
        throw StateError('Daily Note creation requires DailyNoteService.');
      }
      return (await service.openOrCreate(
        workspaceId: page.objectType.workspaceId,
      ))
          .id;
    }
    if (systemKey == PersonObjectBridge.systemKey) {
      final impact = await PersonObjectWriteService.forDatabase(
        pageLoader.genericStore.database,
      ).createWithImpact(workspaceId: page.objectType.workspaceId, name: title);
      await _notifyCommittedPersonObject(impact);
      return impact.canonicalObjectId;
    }
    _rejectIdentitySensitiveGenericCreate(systemKey);
    return objectStore.createObject(
      objectTypeId: page.objectType.id,
      title: title,
    );
  }

  /// Creates or reuses a canonical Weblink from URL input for a collection
  /// whose target ObjectType is the system Weblink type.
  ///
  /// This is intentionally distinct from [create]: title-only creation remains
  /// fail-closed so URL normalization/reuse cannot be bypassed by generic hosts.
  /// Optional resource enrichment runs only after identity establishment and
  /// is explicitly fail-soft so metadata/media errors never roll back creation.
  Future<int> createWeblinkFromUrl({
    required int databaseId,
    required String url,
    String? title,
  }) async {
    final page = await _load(databaseId);
    final systemKey = await _systemKey(page);
    if (systemKey != WeblinkObjectService.systemKey) {
      throw UnsupportedError(
        'URL-based Weblink creation requires a Database collection targeting the system Weblink ObjectType.',
      );
    }
    final service = weblinks;
    if (service == null) {
      throw StateError('Weblink URL creation requires WeblinkObjectService.');
    }
    final object = await CanonicalWeblinkCaptureService(
      weblinks: service,
    ).capture(workspaceId: page.objectType.workspaceId, url: url, title: title);
    final enrich = weblinkCreateEnricher;
    if (enrich != null) {
      try {
        await enrich(
          workspaceId: page.objectType.workspaceId,
          objectId: object.id,
          url: url,
        );
      } catch (_, stackTrace) {
        _debugWeblinkEnrichmentFailure(stackTrace);
      }
    }
    return object.id;
  }

  /// Creates or reuses a canonical Image from an app-managed file for a
  /// collection whose target ObjectType is the system Image type.
  ///
  /// File selection/copying belongs to the import boundary. This method starts
  /// only after a managed [filePath] exists and keeps generic title-only Image
  /// creation fail-closed so file/source identity cannot be bypassed. Optional
  /// storage ownership is accepted only through the closed managed-file
  /// ownership contract; the creator never infers it from the path.
  Future<int> createImageFromManagedFile({
    required int databaseId,
    required String filePath,
    String? sourceUrl,
    String? title,
    String? originalFilename,
    String? contentType,
    int? pixelWidth,
    int? pixelHeight,
    ManagedFileOwnership? storageOwnership,
  }) async {
    final page = await _load(databaseId);
    final systemKey = await _systemKey(page);
    if (systemKey != ImageObjectService.systemKey) {
      throw UnsupportedError(
        'Managed Image creation requires a Database collection targeting the system Image ObjectType.',
      );
    }
    final service = images;
    if (service == null) {
      throw StateError('Managed Image creation requires ImageObjectService.');
    }
    final object = await service.findOrCreateManaged(
      workspaceId: page.objectType.workspaceId,
      filePath: filePath,
      sourceUrl: sourceUrl,
      title: title,
      originalFilename: originalFilename,
      contentType: contentType,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      storageOwnership: storageOwnership,
    );
    return object.id;
  }

  /// Creates or reuses a canonical File from an app-managed file for a
  /// collection whose target ObjectType is the system File type.
  ///
  /// File copying/classification belongs to the import boundary. This keeps
  /// title-only creation fail-closed so managed stored-path identity and
  /// metadata cannot be bypassed. Optional storage ownership
  /// must come from the closed managed-file ownership contract rather than an
  /// arbitrary string or path-location inference.
  Future<int> createFileFromManagedFile({
    required int databaseId,
    required String filePath,
    String? title,
    String? originalFilename,
    String? contentType,
    int? sizeBytes,
    String? sha256,
    DateTime? importedAt,
    ManagedFileOwnership? storageOwnership,
  }) async {
    final page = await _load(databaseId);
    final systemKey = await _systemKey(page);
    if (systemKey != FileObjectService.systemKey) {
      throw UnsupportedError(
        'Managed File creation requires a Database collection targeting the system File ObjectType.',
      );
    }
    final service = files;
    if (service == null) {
      throw StateError('Managed File creation requires FileObjectService.');
    }
    final object = await service.findOrCreateManaged(
      workspaceId: page.objectType.workspaceId,
      filePath: filePath,
      title: title,
      originalFilename: originalFilename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      sha256: sha256,
      importedAt: importedAt,
      storageOwnership: storageOwnership,
    );
    return object.id;
  }

  Future<int> createInGroup({
    required int databaseId,
    required String title,
    required ObjectPropertyDefinition groupProperty,
    required ObjectGroupBucket<AppObject> targetGroup,
  }) async {
    final page = await _load(databaseId);
    final systemKey = await _systemKey(page);
    if (systemKey == DailyNoteService.systemKey) {
      throw UnsupportedError(
        'Daily Notes are date-keyed and cannot be created through a generic Board group.',
      );
    }
    _rejectIdentitySensitiveGenericCreate(systemKey);
    ObjectPropertyDefinition? canonicalProperty;
    for (final property in page.objectType.properties) {
      if (property.id == groupProperty.id) {
        canonicalProperty = property;
        break;
      }
    }
    if (canonicalProperty == null) {
      throw ArgumentError.value(
        groupProperty.id,
        'groupProperty',
        'Board group Property must belong to the Database collection target ObjectType.',
      );
    }

    if (systemKey == PersonObjectBridge.systemKey) {
      PersonCommittedWriteImpact? impact;
      final objectId = await boardCreate.createWithObjectFactory(
        createObject: () async {
          impact =
              await PersonObjectWriteService.forDatabase(
                pageLoader.genericStore.database,
              ).createWithImpact(
                workspaceId: page.objectType.workspaceId,
                name: title,
              );
          return impact!.canonicalObjectId;
        },
        groupProperty: canonicalProperty,
        targetGroup: targetGroup,
      );
      await _notifyCommittedPersonObject(impact);
      return objectId;
    }

    return boardCreate.create(
      objectTypeId: page.objectType.id,
      title: title,
      groupProperty: canonicalProperty,
      targetGroup: targetGroup,
    );
  }

  Future<void> _notifyCommittedPersonObject(
    PersonCommittedWriteImpact? impact,
  ) async {
    if (impact?.canonicalMutationCommitted != true) return;
    await canonicalObjectMutationImpactSink?.objectCommitted(
      impact!.canonicalObjectId,
    );
  }

  void _rejectIdentitySensitiveGenericCreate(String? systemKey) {
    if (systemKey == WeblinkObjectService.systemKey) {
      throw UnsupportedError(
        'Weblinks must be created from a URL so canonical URL normalization and reuse are preserved.',
      );
    }
    if (systemKey == ImageObjectService.systemKey) {
      throw UnsupportedError(
        'Images must be created from managed image/file input so canonical file identity is preserved.',
      );
    }
    if (systemKey == FileObjectService.systemKey) {
      throw UnsupportedError(
        'Files must be created from managed file input so canonical stored-path identity is preserved.',
      );
    }
  }

  Future<String?> _systemKey(GenericDatabaseCollectionPageData page) async {
    final registry = systemObjects;
    if (registry == null) return null;
    return registry.systemKeyForObjectType(page.objectType.id);
  }

  Future<GenericDatabaseCollectionPageData> _load(int databaseId) async {
    final page = await pageLoader.load(databaseId);
    if (page == null) {
      throw ArgumentError.value(
        databaseId,
        'databaseId',
        'Database collection does not exist.',
      );
    }
    return page;
  }

  void _debugWeblinkEnrichmentFailure(StackTrace stackTrace) {
    assert(() {
      developer.log(
        'Optional post-create Weblink enrichment failed; canonical Weblink is kept.',
        name: 'bookmark_app.generic_database_create',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }
}
