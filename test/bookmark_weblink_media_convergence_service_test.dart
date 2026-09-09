import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_weblink_media_convergence_service.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late int workspaceId;
  late ObjectSyncService sync;
  late GenericDatabaseStore genericStore;
  late RelationMutationService mutations;
  late RelationTargetService targets;
  late ImageObjectService images;
  late WeblinkImageSchemaService weblinkImages;
  late BookmarkWeblinkMediaConvergenceService convergence;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    sync = ObjectSyncService(database);
    genericStore = GenericDatabaseStore(database);
    mutations = RelationMutationService(
      objectStore: sync.objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: sync.objectStore,
      ),
    );
    targets = RelationTargetService(sync.objectStore);
    images = ImageObjectService(
      systemObjects: sync.systemObjectStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    weblinkImages = WeblinkImageSchemaService(
      systemObjects: sync.systemObjectStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    convergence = sync.bookmarkWeblinkMedia;
  });

  tearDown(() async {
    await sync.dispose();
    await database.close();
  });

  test(
    'ordered Images and Cover converge once and remain idempotent',
    () async {
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/media',
        title: 'Media',
      );
      await _syncPrerequisites(sync, workspaceId);
      final firstImage = await _createImage(
        images,
        workspaceId,
        'First',
        'images/first.png',
      );
      final secondImage = await _createImage(
        images,
        workspaceId,
        'Second',
        'images/second.png',
      );
      await _setBookmarkMedia(
        database: database,
        sync: sync,
        mutations: mutations,
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
        imageObjectIds: <int>[firstImage.id, secondImage.id],
        coverImageObjectId: secondImage.id,
      );

      final first = await convergence.reconcileWorkspace(workspaceId);

      expect(first.bookmarkCount, 1);
      expect(first.weblinkCount, 1);
      expect(first.convergedWeblinkCount, 1);
      expect(first.unchangedWeblinkCount, 0);
      expect(first.mutatedWeblinkObjectIds, hasLength(1));
      final state = await _canonicalMediaState(
        sync: sync,
        targets: targets,
        weblinkImages: weblinkImages,
        workspaceId: workspaceId,
      );
      expect(state.imageObjectIds, <int>[firstImage.id, secondImage.id]);
      expect(state.coverImageObjectId, secondImage.id);
      expect(state.imageObjectIds, contains(state.coverImageObjectId));

      final second = await convergence.reconcileWorkspace(workspaceId);
      expect(second.convergedWeblinkCount, 0);
      expect(second.unchangedWeblinkCount, 1);
      expect(second.mutatedWeblinkObjectIds, isEmpty);
      expect(
        (await _canonicalMediaState(
          sync: sync,
          targets: targets,
          weblinkImages: weblinkImages,
          workspaceId: workspaceId,
        )).imageObjectIds,
        state.imageObjectIds,
      );
    },
  );

  test(
    'empty Images and no Cover do not invent representative media',
    () async {
      await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/empty-media',
        title: 'Empty media',
      );
      await _syncPrerequisites(sync, workspaceId);

      final report = await convergence.reconcileWorkspace(workspaceId);

      expect(report.bookmarkCount, 1);
      expect(report.weblinkCount, 1);
      expect(report.convergedWeblinkCount, 0);
      expect(report.unchangedWeblinkCount, 1);
      final state = await _canonicalMediaState(
        sync: sync,
        targets: targets,
        weblinkImages: weblinkImages,
        workspaceId: workspaceId,
      );
      expect(state.imageObjectIds, isEmpty);
      expect(state.coverImageObjectId, isNull);
    },
  );

  test(
    'equivalent media on Bookmarks sharing one Weblink converges once',
    () async {
      final firstBookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'HTTPS://EXAMPLE.COM:443/shared-media',
        title: 'First shared',
      );
      final secondBookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/shared-media',
        title: 'Second shared',
      );
      await _syncPrerequisites(sync, workspaceId);
      final firstImage = await _createImage(
        images,
        workspaceId,
        'Shared first',
        'images/shared-first.png',
      );
      final secondImage = await _createImage(
        images,
        workspaceId,
        'Shared second',
        'images/shared-second.png',
      );
      for (final bookmarkId in <int>[firstBookmarkId, secondBookmarkId]) {
        await _setBookmarkMedia(
          database: database,
          sync: sync,
          mutations: mutations,
          workspaceId: workspaceId,
          bookmarkId: bookmarkId,
          imageObjectIds: <int>[firstImage.id, secondImage.id],
          coverImageObjectId: firstImage.id,
        );
      }

      final report = await convergence.reconcileWorkspace(workspaceId);

      expect(report.bookmarkCount, 2);
      expect(report.weblinkCount, 1);
      expect(report.convergedWeblinkCount, 1);
      expect(report.mutatedWeblinkObjectIds, hasLength(1));
    },
  );

  test(
    'conflicting Bookmark media fail closed before target schema mutation',
    () async {
      final firstBookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/media-conflict',
        title: 'First conflict',
      );
      final secondBookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'HTTPS://EXAMPLE.COM:443/media-conflict',
        title: 'Second conflict',
      );
      await _syncPrerequisites(sync, workspaceId);
      final firstImage = await _createImage(
        images,
        workspaceId,
        'Conflict first',
        'images/conflict-first.png',
      );
      final secondImage = await _createImage(
        images,
        workspaceId,
        'Conflict second',
        'images/conflict-second.png',
      );
      await _setBookmarkMedia(
        database: database,
        sync: sync,
        mutations: mutations,
        workspaceId: workspaceId,
        bookmarkId: firstBookmarkId,
        imageObjectIds: <int>[firstImage.id],
        coverImageObjectId: firstImage.id,
      );
      await _setBookmarkMedia(
        database: database,
        sync: sync,
        mutations: mutations,
        workspaceId: workspaceId,
        bookmarkId: secondBookmarkId,
        imageObjectIds: <int>[secondImage.id],
        coverImageObjectId: secondImage.id,
      );

      await expectLater(
        convergence.reconcileWorkspace(workspaceId),
        throwsStateError,
      );

      await _expectNoWeblinkMediaSchema(sync, workspaceId);
    },
  );

  test(
    'pre-existing different Weblink media are preserved on conflict',
    () async {
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/media-preserved',
        title: 'Preserved media',
      );
      await _syncPrerequisites(sync, workspaceId);
      final sourceImage = await _createImage(
        images,
        workspaceId,
        'Source media',
        'images/source-media.png',
      );
      final targetImage = await _createImage(
        images,
        workspaceId,
        'Target media',
        'images/target-media.png',
      );
      await _setBookmarkMedia(
        database: database,
        sync: sync,
        mutations: mutations,
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
        imageObjectIds: <int>[sourceImage.id],
        coverImageObjectId: sourceImage.id,
      );
      await _setWeblinkMedia(
        sync: sync,
        mutations: mutations,
        weblinkImages: weblinkImages,
        workspaceId: workspaceId,
        imageObjectIds: <int>[targetImage.id],
        representativeImageObjectId: targetImage.id,
      );

      await expectLater(
        convergence.reconcileWorkspace(workspaceId),
        throwsStateError,
      );

      final state = await _canonicalMediaState(
        sync: sync,
        targets: targets,
        weblinkImages: weblinkImages,
        workspaceId: workspaceId,
      );
      expect(state.imageObjectIds, <int>[targetImage.id]);
      expect(state.coverImageObjectId, targetImage.id);
    },
  );

  test(
    'source-only media change advances target with prior snapshot',
    () async {
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/media-change',
        title: 'Media change',
      );
      await _syncPrerequisites(sync, workspaceId);
      final beforeImage = await _createImage(
        images,
        workspaceId,
        'Before media',
        'images/before-media.png',
      );
      final afterImage = await _createImage(
        images,
        workspaceId,
        'After media',
        'images/after-media.png',
      );
      await _setBookmarkMedia(
        database: database,
        sync: sync,
        mutations: mutations,
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
        imageObjectIds: <int>[beforeImage.id],
        coverImageObjectId: beforeImage.id,
      );
      await convergence.reconcileWorkspace(workspaceId);
      final previous = await convergence.captureSourceSnapshot(workspaceId);
      final bookmarkObjectId = await _bookmarkObjectId(
        database,
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
      );

      await _setBookmarkMedia(
        database: database,
        sync: sync,
        mutations: mutations,
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
        imageObjectIds: <int>[afterImage.id],
        coverImageObjectId: afterImage.id,
      );
      final report = await convergence.reconcileBookmarkObjects(
        workspaceId,
        bookmarkObjectIds: <int>[bookmarkObjectId],
        previousSource: previous,
      );

      expect(report.convergedWeblinkCount, 1);
      final state = await _canonicalMediaState(
        sync: sync,
        targets: targets,
        weblinkImages: weblinkImages,
        workspaceId: workspaceId,
      );
      expect(state.imageObjectIds, <int>[afterImage.id]);
      expect(state.coverImageObjectId, afterImage.id);
    },
  );

  test(
    'canonical-only Representative edit stays independent of Related images',
    () async {
      final bookmarkId = await _createBookmark(
        database,
        workspaceId: workspaceId,
        url: 'https://example.com/preview-media',
        title: 'Preview media',
      );
      await _syncPrerequisites(sync, workspaceId);
      final sourceImage = await _createImage(
        images,
        workspaceId,
        'Source image',
        'images/source-image.png',
      );
      final previewImage = await _createImage(
        images,
        workspaceId,
        'Preview image',
        'images/preview-image.png',
      );
      await _setBookmarkMedia(
        database: database,
        sync: sync,
        mutations: mutations,
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
        imageObjectIds: <int>[sourceImage.id],
        coverImageObjectId: sourceImage.id,
      );
      await convergence.reconcileWorkspace(workspaceId);
      final previous = await convergence.captureSourceSnapshot(workspaceId);
      final bookmarkObjectId = await _bookmarkObjectId(
        database,
        workspaceId: workspaceId,
        bookmarkId: bookmarkId,
      );
      final targetSchema = await weblinkImages.ensureDefinition(workspaceId);
      final weblinkObjectId = await _singleWeblinkObjectId(sync, workspaceId);
      await mutations.setRelation(
        objectId: weblinkObjectId,
        property: targetSchema.representativeImageProperty,
        targetObjectIds: <int>[previewImage.id],
      );

      final report = await convergence.reconcileBookmarkObjects(
        workspaceId,
        bookmarkObjectIds: <int>[bookmarkObjectId],
        previousSource: previous,
      );

      expect(report.convergedWeblinkCount, 0);
      expect(report.unchangedWeblinkCount, 1);
      final state = await _canonicalMediaState(
        sync: sync,
        targets: targets,
        weblinkImages: weblinkImages,
        workspaceId: workspaceId,
      );
      expect(state.imageObjectIds, <int>[sourceImage.id]);
      expect(state.coverImageObjectId, previewImage.id);
      expect(state.imageObjectIds, isNot(contains(previewImage.id)));
    },
  );

  test('source and target Relation index drift fail closed', () async {
    final bookmarkId = await _createBookmark(
      database,
      workspaceId: workspaceId,
      url: 'https://example.com/media-drift',
      title: 'Media drift',
    );
    await _syncPrerequisites(sync, workspaceId);
    final image = await _createImage(
      images,
      workspaceId,
      'Drift image',
      'images/drift-image.png',
    );
    await _setBookmarkMedia(
      database: database,
      sync: sync,
      mutations: mutations,
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
      imageObjectIds: <int>[image.id],
      coverImageObjectId: image.id,
    );

    final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    ))!;
    final imagesProperty = bookmarkType.properties.singleWhere(
      (property) => property.name == 'Images',
    );
    final bookmarkObjectId = await _bookmarkObjectId(
      database,
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    );
    await database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      <Object>[bookmarkObjectId, imagesProperty.id],
    );

    await expectLater(
      convergence.reconcileWorkspace(workspaceId),
      throwsStateError,
    );
    await _expectNoWeblinkMediaSchema(sync, workspaceId);

    await mutations.setRelation(
      objectId: bookmarkObjectId,
      property: imagesProperty,
      targetObjectIds: <int>[image.id],
    );
    await convergence.reconcileWorkspace(workspaceId);
    final targetSchema = await weblinkImages.ensureDefinition(workspaceId);
    final weblinkObjectId = await _singleWeblinkObjectId(sync, workspaceId);
    await database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      <Object>[weblinkObjectId, targetSchema.relatedImagesProperty.id],
    );

    await expectLater(
      convergence.reconcileWorkspace(workspaceId),
      throwsStateError,
    );
  });
}

Future<void> _syncPrerequisites(ObjectSyncService sync, int workspaceId) async {
  await sync.coreBridge.syncAll(workspaceId);
  await sync.bookmarkWeblinkBridge.syncWorkspace(workspaceId);
}

Future<int> _createBookmark(
  AppDatabase database, {
  required int workspaceId,
  required String url,
  required String title,
}) async {
  await database.customStatement(
    'INSERT INTO bookmarks(url, title) VALUES (?, ?)',
    <Object>[url, title],
  );
  final id =
      (await database
              .customSelect(
                'SELECT id FROM bookmarks WHERE title = ? ORDER BY id DESC LIMIT 1',
                variables: <Variable<Object>>[Variable<String>(title)],
              )
              .getSingle())
          .read<int>('id');
  await database.customStatement(
    'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
    <Object>[id, workspaceId],
  );
  return id;
}

Future<AppObject> _createImage(
  ImageObjectService images,
  int workspaceId,
  String title,
  String filePath,
) => images.findOrCreateManaged(
  workspaceId: workspaceId,
  filePath: filePath,
  title: title,
  originalFilename: filePath.split('/').last,
);

Future<int> _bookmarkObjectId(
  AppDatabase database, {
  required int workspaceId,
  required int bookmarkId,
}) async =>
    (await database
            .customSelect(
              '''SELECT object_id
                 FROM bookmark_object_links
                 WHERE workspace_id = ? AND bookmark_id = ?''',
              variables: <Variable<Object>>[
                Variable<int>(workspaceId),
                Variable<int>(bookmarkId),
              ],
            )
            .getSingle())
        .read<int>('object_id');

Future<void> _setBookmarkMedia({
  required AppDatabase database,
  required ObjectSyncService sync,
  required RelationMutationService mutations,
  required int workspaceId,
  required int bookmarkId,
  required List<int> imageObjectIds,
  required int? coverImageObjectId,
}) async {
  if (coverImageObjectId != null &&
      !imageObjectIds.contains(coverImageObjectId)) {
    throw ArgumentError('Cover must be included in Images.');
  }
  final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
    workspaceId: workspaceId,
    systemKey: CoreObjectBridge.bookmarkSystemKey,
  ))!;
  final imagesProperty = bookmarkType.properties.singleWhere(
    (property) => property.name == 'Images',
  );
  final coverProperty = bookmarkType.properties.singleWhere(
    (property) => property.name == 'Cover Image',
  );
  final bookmarkObjectId = await _bookmarkObjectId(
    database,
    workspaceId: workspaceId,
    bookmarkId: bookmarkId,
  );
  await mutations.setRelation(
    objectId: bookmarkObjectId,
    property: imagesProperty,
    targetObjectIds: imageObjectIds,
  );
  await mutations.setRelation(
    objectId: bookmarkObjectId,
    property: coverProperty,
    targetObjectIds: coverImageObjectId == null
        ? const <int>[]
        : <int>[coverImageObjectId],
  );
}

Future<void> _setWeblinkMedia({
  required ObjectSyncService sync,
  required RelationMutationService mutations,
  required WeblinkImageSchemaService weblinkImages,
  required int workspaceId,
  required List<int> imageObjectIds,
  required int? representativeImageObjectId,
}) async {
  final schema = await weblinkImages.ensureDefinition(workspaceId);
  final weblinkObjectId = await _singleWeblinkObjectId(sync, workspaceId);
  await mutations.setRelation(
    objectId: weblinkObjectId,
    property: schema.relatedImagesProperty,
    targetObjectIds: imageObjectIds,
  );
  await mutations.setRelation(
    objectId: weblinkObjectId,
    property: schema.representativeImageProperty,
    targetObjectIds: representativeImageObjectId == null
        ? const <int>[]
        : <int>[representativeImageObjectId],
  );
}

Future<int> _singleWeblinkObjectId(
  ObjectSyncService sync,
  int workspaceId,
) async {
  final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
    workspaceId: workspaceId,
    systemKey: WeblinkObjectService.systemKey,
  ))!;
  return (await sync.objectStore.listObjects(weblinkType.id)).single.id;
}

Future<BookmarkWeblinkMediaState> _canonicalMediaState({
  required ObjectSyncService sync,
  required RelationTargetService targets,
  required WeblinkImageSchemaService weblinkImages,
  required int workspaceId,
}) async {
  final schema = await weblinkImages.ensureDefinition(workspaceId);
  final weblinkObjectId = await _singleWeblinkObjectId(sync, workspaceId);
  final related = await targets.selectionForMutation(
    workspaceId: workspaceId,
    sourceObjectId: weblinkObjectId,
    property: schema.relatedImagesProperty,
  );
  final representative = await targets.selectionForMutation(
    workspaceId: workspaceId,
    sourceObjectId: weblinkObjectId,
    property: schema.representativeImageProperty,
  );
  return BookmarkWeblinkMediaState(
    imageObjectIds: related.selectedObjectIds,
    coverImageObjectId: representative.selectedObjectIds.isEmpty
        ? null
        : representative.selectedObjectIds.single,
  );
}

Future<void> _expectNoWeblinkMediaSchema(
  ObjectSyncService sync,
  int workspaceId,
) async {
  final weblinkType = await sync.systemObjectStore.getSystemObjectType(
    workspaceId: workspaceId,
    systemKey: WeblinkObjectService.systemKey,
  );
  expect(weblinkType, isNotNull);
  expect(
    weblinkType!.properties.where(
      (property) =>
          property.name == WeblinkImageSchemaService.relatedImagesName ||
          property.name == WeblinkImageSchemaService.representativeImageName,
    ),
    isEmpty,
  );
}
