import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/bookmark_image_relation_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Bookmark Image save rejects edge drift without changing Relations or legacy projection',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final state = (await fixture.service.load(
        workspaceId: fixture.workspaceId,
        bookmarkId: fixture.bookmarkId,
      ))!;
      final nativeImage = await fixture.images.findOrCreateManaged(
        workspaceId: fixture.workspaceId,
        filePath: 'images/integrity-native.png',
        title: 'Native integrity image',
        originalFilename: 'integrity-native.png',
      );

      await fixture.database.customStatement(
        'UPDATE object_relation_edges SET position = 7 '
        'WHERE source_object_id = ? AND property_id = ?',
        <Object>[fixture.bookmarkObjectId, fixture.imagesProperty.id],
      );

      final before = await _snapshot(fixture);

      await expectLater(
        fixture.service.saveImages(
          state: state,
          selectedObjectIds: <int>[
            fixture.legacyImageObjectId,
            nativeImage.id,
          ],
        ),
        throwsStateError,
      );

      expect(await _snapshot(fixture), before);
    },
  );

  test(
    'canonical Bookmark create path rejects corrupt Cover before syncAll can overwrite it',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final secondImage = await fixture.images.findOrCreateManaged(
        workspaceId: fixture.workspaceId,
        filePath: 'images/integrity-second.png',
        title: 'Second integrity image',
        originalFilename: 'integrity-second.png',
      );

      // Build a persisted single-Relation cardinality corruption whose stored
      // value and normalized index agree with each other. Without the create-path
      // preflight, CoreObjectBridge sees the corrupt Cover as an empty fail-closed
      // read and can rewrite it from bookmark_photos during syncAll().
      await fixture.genericStore.setValue(
        recordId: fixture.bookmarkObjectId,
        propertyId: fixture.coverProperty.id,
        value: <int>[fixture.legacyImageObjectId, secondImage.id],
      );
      await fixture.database.customStatement(
        '''INSERT INTO object_relation_edges(
             source_object_id, property_id, target_object_id, position
           ) VALUES (?, ?, ?, ?)''',
        <Object>[
          fixture.bookmarkObjectId,
          fixture.coverProperty.id,
          secondImage.id,
          1,
        ],
      );

      final before = await _snapshot(fixture);

      await expectLater(
        fixture.service.saveImagesAfterCreate(
          workspaceId: fixture.workspaceId,
          bookmarkId: fixture.bookmarkId,
          imageObjectIds: <int>[fixture.legacyImageObjectId],
          coverImageObjectId: fixture.legacyImageObjectId,
        ),
        throwsStateError,
      );

      expect(await _snapshot(fixture), before);
    },
  );
}

Future<_Fixture> _fixture() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final workspaceId = await WorkspaceStore(database).initialize();
  final genericStore = GenericDatabaseStore(database);
  final objectStore = ObjectStore(genericStore);
  final systemStore = SystemObjectStore(
    database: database,
    objectStore: objectStore,
  );
  final bridge = CoreObjectBridge(
    database: database,
    objectStore: objectStore,
    systemObjectStore: systemStore,
    tagBridge: TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
    ),
  );

  await database.customStatement(
    "INSERT INTO photos(path, title) VALUES ('photos/integrity-legacy.jpg', 'Integrity legacy photo')",
  );
  final legacyPhotoId = (await database.customSelect(
    "SELECT id FROM photos WHERE path = 'photos/integrity-legacy.jpg'",
  ).getSingle())
      .read<int>('id');
  await database.customStatement(
    "INSERT INTO bookmarks(url, title) VALUES ('https://relation-integrity.example', 'Integrity Bookmark')",
  );
  final bookmarkId = (await database.customSelect(
    "SELECT id FROM bookmarks WHERE url = 'https://relation-integrity.example'",
  ).getSingle())
      .read<int>('id');
  await database.customStatement(
    'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
    <Object>[bookmarkId, workspaceId],
  );
  await database.customStatement(
    'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
    <Object>[bookmarkId, legacyPhotoId],
  );

  await bridge.syncAll(workspaceId);

  final bookmarkObjectId = (await database.customSelect(
    '''SELECT object_id
       FROM bookmark_object_links
       WHERE workspace_id = ? AND bookmark_id = ?''',
    variables: <Variable<int>>[
      Variable<int>(workspaceId),
      Variable<int>(bookmarkId),
    ],
  ).getSingle())
      .read<int>('object_id');
  final legacyImageObjectId = (await database.customSelect(
    '''SELECT object_id
       FROM photo_object_links
       WHERE workspace_id = ? AND photo_id = ?''',
    variables: <Variable<int>>[
      Variable<int>(workspaceId),
      Variable<int>(legacyPhotoId),
    ],
  ).getSingle())
      .read<int>('object_id');
  final bookmarkType = (await systemStore.getSystemObjectType(
    workspaceId: workspaceId,
    systemKey: CoreObjectBridge.bookmarkSystemKey,
  ))!;
  final imagesProperty = bookmarkType.properties.singleWhere(
    (property) => property.name == 'Images',
  );
  final coverProperty = bookmarkType.properties.singleWhere(
    (property) => property.name == 'Cover Image',
  );
  final images = ImageObjectService(
    systemObjects: systemStore,
    defaultsStore: ObjectTypeDefaultsStore(genericStore),
  );

  return _Fixture(
    database: database,
    workspaceId: workspaceId,
    bookmarkId: bookmarkId,
    bookmarkObjectId: bookmarkObjectId,
    legacyImageObjectId: legacyImageObjectId,
    bookmarkType: bookmarkType,
    imagesProperty: imagesProperty,
    coverProperty: coverProperty,
    genericStore: genericStore,
    images: images,
    service: BookmarkImageRelationService(database),
  );
}

Future<_Snapshot> _snapshot(_Fixture fixture) async {
  return _Snapshot(
    imagesValue: await _storedValue(fixture, fixture.imagesProperty),
    coverValue: await _storedValue(fixture, fixture.coverProperty),
    imagesEdges: await _edgeSnapshot(fixture, fixture.imagesProperty),
    coverEdges: await _edgeSnapshot(fixture, fixture.coverProperty),
    legacyProjection: await _legacyProjectionSnapshot(fixture),
  );
}

Future<String> _storedValue(
  _Fixture fixture,
  ObjectPropertyDefinition property,
) async {
  final record = (await fixture.genericStore.listRecords(fixture.bookmarkType.id))
      .singleWhere((candidate) => candidate.id == fixture.bookmarkObjectId);
  return jsonEncode(record.values[property.id]);
}

Future<List<String>> _edgeSnapshot(
  _Fixture fixture,
  ObjectPropertyDefinition property,
) async {
  final rows = await fixture.database.customSelect(
    '''SELECT target_object_id, position
       FROM object_relation_edges
       WHERE source_object_id = ? AND property_id = ?
       ORDER BY position, target_object_id''',
    variables: <Variable<int>>[
      Variable<int>(fixture.bookmarkObjectId),
      Variable<int>(property.id),
    ],
  ).get();
  return rows
      .map(
        (row) =>
            '${row.read<int>('target_object_id')}:${row.read<int>('position')}',
      )
      .toList(growable: false);
}

Future<List<String>> _legacyProjectionSnapshot(_Fixture fixture) async {
  final rows = await fixture.database.customSelect(
    '''SELECT photo_id, is_cover
       FROM bookmark_photos
       WHERE bookmark_id = ?
       ORDER BY photo_id''',
    variables: <Variable<int>>[Variable<int>(fixture.bookmarkId)],
  ).get();
  return rows
      .map(
        (row) => '${row.read<int>('photo_id')}:${row.read<int>('is_cover')}',
      )
      .toList(growable: false);
}

class _Snapshot {
  const _Snapshot({
    required this.imagesValue,
    required this.coverValue,
    required this.imagesEdges,
    required this.coverEdges,
    required this.legacyProjection,
  });

  final String imagesValue;
  final String coverValue;
  final List<String> imagesEdges;
  final List<String> coverEdges;
  final List<String> legacyProjection;

  @override
  bool operator ==(Object other) =>
      other is _Snapshot &&
      imagesValue == other.imagesValue &&
      coverValue == other.coverValue &&
      _listEquals(imagesEdges, other.imagesEdges) &&
      _listEquals(coverEdges, other.coverEdges) &&
      _listEquals(legacyProjection, other.legacyProjection);

  @override
  int get hashCode => Object.hash(
        imagesValue,
        coverValue,
        Object.hashAll(imagesEdges),
        Object.hashAll(coverEdges),
        Object.hashAll(legacyProjection),
      );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.workspaceId,
    required this.bookmarkId,
    required this.bookmarkObjectId,
    required this.legacyImageObjectId,
    required this.bookmarkType,
    required this.imagesProperty,
    required this.coverProperty,
    required this.genericStore,
    required this.images,
    required this.service,
  });

  final AppDatabase database;
  final int workspaceId;
  final int bookmarkId;
  final int bookmarkObjectId;
  final int legacyImageObjectId;
  final AppObjectType bookmarkType;
  final ObjectPropertyDefinition imagesProperty;
  final ObjectPropertyDefinition coverProperty;
  final GenericDatabaseStore genericStore;
  final ImageObjectService images;
  final BookmarkImageRelationService service;
}
