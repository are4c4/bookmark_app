import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing legacy Photo file skips first promotion and retries later',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('missing_photo_promotion_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: directory.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();

    const storedPath = 'managed/retry.png';
    await database.customStatement(
      'INSERT INTO photos(path, title, note) VALUES (?, ?, ?)',
      const <Object>[storedPath, 'Retry image', 'keep legacy metadata'],
    );
    final photoId = (await database.customSelect(
      'SELECT id FROM photos LIMIT 1',
    ).getSingle())
        .read<int>('id');

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);
    await sync.syncWorkspace(workspaceId);

    final imageType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.photoSystemKey,
    ))!;
    expect(await sync.objectStore.listObjects(imageType.id), isEmpty);
    expect(
      await database.customSelect(
        'SELECT object_id FROM photo_object_links WHERE workspace_id = ? AND photo_id = ?',
        variables: [],
      ).get(),
      isEmpty,
    );
    expect(
      (await database.customSelect(
        'SELECT COUNT(*) AS count FROM photos WHERE id = $photoId',
      ).getSingle())
          .read<int>('count'),
      1,
      reason: 'Missing media must never delete or rewrite the legacy Photo row.',
    );

    final managedFile = File('${directory.path}/$storedPath');
    await managedFile.parent.create(recursive: true);
    await managedFile.writeAsBytes(const <int>[1, 2, 3]);

    await sync.syncWorkspace(workspaceId);

    final images = await sync.objectStore.listObjects(imageType.id);
    expect(images, hasLength(1));
    final fileProperty =
        imageType.properties.singleWhere((property) => property.name == 'File');
    expect(images.single.values[fileProperty.id], storedPath);
    final links = await database.customSelect(
      'SELECT object_id FROM photo_object_links WHERE workspace_id = $workspaceId AND photo_id = $photoId',
    ).get();
    expect(links, hasLength(1));
    expect(links.single.read<int>('object_id'), images.single.id);
  });
}
