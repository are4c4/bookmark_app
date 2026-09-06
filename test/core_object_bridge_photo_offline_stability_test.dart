import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/image_visual_resolver.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('promoted Photo mapping survives temporary managed-file loss', () async {
    final directory = await Directory.systemTemp.createTemp(
      'photo_promotion_offline_stability_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/photos/stable.jpg');
    await managedFile.parent.create(recursive: true);
    await managedFile.writeAsBytes(const <int>[1, 2, 3]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: directory.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
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
      "INSERT INTO photos(path, title) VALUES ('photos/stable.jpg', 'Stable legacy')",
    );
    final photoId = (await database.customSelect(
      "SELECT id FROM photos WHERE path = 'photos/stable.jpg'",
    ).getSingle())
        .read<int>('id');

    await bridge.syncAll(workspaceId);
    final imageType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    final promoted = (await objectStore.listObjects(imageType.id)).single;
    final initialLink = await database.customSelect(
      'SELECT object_id FROM photo_object_links '
      'WHERE workspace_id = ? AND photo_id = ?',
      variables: [Variable<int>(workspaceId), Variable<int>(photoId)],
    ).getSingle();
    expect(initialLink.read<int>('object_id'), promoted.id);

    await managedFile.delete();
    await bridge.syncAll(workspaceId);

    final whileMissing = await objectStore.listObjects(imageType.id);
    expect(whileMissing, hasLength(1));
    expect(whileMissing.single.id, promoted.id);
    final stableLink = await database.customSelect(
      'SELECT object_id FROM photo_object_links '
      'WHERE workspace_id = ? AND photo_id = ?',
      variables: [Variable<int>(workspaceId), Variable<int>(photoId)],
    ).getSingle();
    expect(stableLink.read<int>('object_id'), promoted.id);
    expect(
      await ImageVisualResolver(objectStore).resolveManaged(
        imageObjectTypeId: imageType.id,
        imageObjectId: promoted.id,
      ),
      isNull,
    );

    await managedFile.writeAsBytes(const <int>[4, 5, 6]);
    await bridge.syncAll(workspaceId);

    final recovered = await objectStore.listObjects(imageType.id);
    expect(recovered, hasLength(1));
    expect(recovered.single.id, promoted.id);
    final visual = await ImageVisualResolver(objectStore).resolveManaged(
      imageObjectTypeId: imageType.id,
      imageObjectId: promoted.id,
    );
    expect(visual, isNotNull);
    expect(visual?.filePath, managedFile.path);
  });
}
