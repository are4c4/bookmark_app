import 'dart:developer' as developer;

import '../domain/object_group.dart';
import '../domain/object_model.dart';
import 'daily_note_service.dart';
import 'generic_database_collection_page_data.dart';
import 'image_object_service.dart';
import 'object_board_create_service.dart';
import 'object_store.dart';
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
    this.weblinkCreateEnricher,
  });

  final GenericDatabaseCollectionPageLoader pageLoader;
  final ObjectStore objectStore;
  final ObjectBoardCreateService boardCreate;
  final SystemObjectStore? systemObjects;
  final DailyNoteService? dailyNotes;
  final WeblinkObjectService? weblinks;
  final ImageObjectService? images;
  final GenericDatabaseWeblinkCreateEnricher? weblinkCreateEnricher;

  /// Returns the user-facing creation contract for an ObjectType.
  ///
  /// Generic hosts can use this to choose the correct affordance without
  /// duplicating system-key knowledge. Identity-sensitive system collections
  /// stay explicit: Weblinks require URL input and Images require managed file
  /// input, while Daily Notes keep their date-keyed open-or-create behavior.
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
      _ => GenericDatabaseCreateMode.generic,
    };
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
  /// Optional resource enrichment runs only after canonical identity exists and
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
    final object = await service.findOrCreate(
      workspaceId: page.objectType.workspaceId,
      url: url,
      title: title,
    );
    final enrich = weblinkCreateEnricher;
    if (enrich != null) {
      try {
        await enrich(
          workspaceId: page.objectType.workspaceId,
          objectId: object.id,
          url: url,
        );
      } catch (error, stackTrace) {
        _debugWeblinkEnrichmentFailure(error, stackTrace);
      }
    }
    return object.id;
  }

  /// Creates or reuses a canonical Image from an app-managed file for a
  /// collection whose target ObjectType is the system Image type.
  ///
  /// File selection/copying belongs to the import boundary. This method starts
  /// only after a managed [filePath] exists and keeps generic title-only Image
  /// creation fail-closed so file/source identity cannot be bypassed.
  Future<int> createImageFromManagedFile({
    required int databaseId,
    required String filePath,
    String? sourceUrl,
    String? title,
    String? originalFilename,
    String? contentType,
    int? pixelWidth,
    int? pixelHeight,
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

    return boardCreate.create(
      objectTypeId: page.objectType.id,
      title: title,
      groupProperty: canonicalProperty,
      targetGroup: targetGroup,
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

  void _debugWeblinkEnrichmentFailure(
    Object error,
    StackTrace stackTrace,
  ) {
    assert(() {
      developer.log(
        'Optional post-create Weblink enrichment failed; canonical Weblink is kept.',
        name: 'bookmark_app.generic_database_create',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }());
  }
}
