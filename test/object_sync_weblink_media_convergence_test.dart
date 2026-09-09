import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace sync converges legacy Bookmark media and reports Weblink impact on change', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final firstPhotoId = await _createPhoto(
      database,
      path: 'photos/first.jpg',
      title: 'First photo',
    );
    final bookmarkId = await _createBookmark(
      database,
      workspaceId: workspaceId,
      url: 'https://example.com/object-sync-media',
      title: 'Object sync media',
    );
    await database.customStatement(
      'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
      <Object>[bookmarkId, firstPhotoId],
    );

    final observedImpacts = <Set<int>>[];
    final sync = ObjectSyncService(
      database,
      onCanonicalObjectsMirrored: (objectIds) async {
        observedImpacts.add(objectIds.toSet());
      },
    );
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);

    final firstImageObjectId = await _imageObjectIdForPhoto(
      database,
      workspaceId: workspaceId,
      photoId: firstPhotoId,
    );
    final weblinkObjectId = await _singleWeblinkObjectId(sync, workspaceId);
    var target = await _targetState(sync, workspaceId);
    expect(target.relatedImageObjectIds, <int>[firstImageObjectId]);
    expect(target.representativeImageObjectId, firstImageObjectId);
    expect(observedImpacts, isEmpty);

    final secondPhotoId = await _createPhoto(
      database,
      path: 'photos/second.jpg',
      title: 'Second photo',
    );
    await database.customStatement(
      'DELETE FROM bookmark_photos WHERE bookmark_id = ?',
      <Object>[bookmarkId],
    );
    await database.customStatement(
      'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
      <Object>[bookmarkId, secondPhotoId],
    );

    await sync.syncWorkspace(workspaceId);

    final secondImageObjectId = await _imageObjectIdForPhoto(
      database,
      workspaceId: workspaceId,
      photoId: secondPhotoId,
    );
    target = await _targetState(sync, workspaceId);
    expect(target.relatedImageObjectIds, <int>[secondImageObjectId]);
    expect(target.representativeImageObjectId, secondImageObjectId);
    expect(
      observedImpacts.any((objectIds) => objectIds.contains(weblinkObjectId)),
      isTrue,
    );

    observedImpacts.clear();
    await sync.syncWorkspace(workspaceId);
    expect(observedImpacts, isEmpty);
  });
}

Future<int> _createPhoto(
  AppDatabase database, {
  required String path,
  required String title,
}) async {
  await database.customStatement(
    'INSERT INTO photos(path, title) VALUES (?, ?)',
    <Object>[path, title],
  );
  return (await database
          .customSelect(
            'SELECT id FROM photos WHERE path = ?',
            variables: <Variable<Object>>[Variable<String>(path)],
          )
          .getSingle())
      .read<int>('id');
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

Future<int> _imageObjectIdForPhoto(
  AppDatabase database, {
  required int workspaceId,
  required int photoId,
}) async =>
    (await database
            .customSelect(
              '''SELECT object_id
                 FROM photo_object_links
                 WHERE workspace_id = ? AND photo_id = ?''',
              variables: <Variable<Object>>[
                Variable<int>(workspaceId),
                Variable<int>(photoId),
              ],
            )
            .getSingle())
        .read<int>('object_id');

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

Future<_TargetState> _targetState(
  ObjectSyncService sync,
  int workspaceId,
) async {
  final genericStore = GenericDatabaseStore(sync.database);
  final schema = await WeblinkImageSchemaService(
    systemObjects: sync.systemObjectStore,
    defaultsStore: ObjectTypeDefaultsStore(genericStore),
  ).ensureDefinition(workspaceId);
  final weblinkObjectId = await _singleWeblinkObjectId(sync, workspaceId);
  final targets = RelationTargetService(sync.objectStore);
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
  return _TargetState(
    relatedImageObjectIds: related.selectedObjectIds,
    representativeImageObjectId: representative.selectedObjectIds.isEmpty
        ? null
        : representative.selectedObjectIds.single,
  );
}

class _TargetState {
  _TargetState({
    required Iterable<int> relatedImageObjectIds,
    required this.representativeImageObjectId,
  }) : relatedImageObjectIds = List<int>.unmodifiable(relatedImageObjectIds);

  final List<int> relatedImageObjectIds;
  final int? representativeImageObjectId;
}
