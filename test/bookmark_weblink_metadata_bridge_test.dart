import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark metadata seeds reusable Weblink fields without later overwrite',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    const url = 'https://Example.com/article';
    await database.customStatement(
      '''INSERT INTO bookmarks(url, title, description, thumbnail)
         VALUES (?, ?, ?, ?)''',
      <Object>[
        url,
        'First resource title',
        'First resource description',
        'not an absolute preview URL',
      ],
    );
    await database.customStatement(
      '''INSERT INTO bookmarks(url, title, description, thumbnail)
         VALUES (?, ?, ?, ?)''',
      <Object>[
        url,
        'Second bookmark title',
        'Second bookmark description',
        'HTTPS://CDN.Example.com:443/a/../preview.jpg?sig=1',
      ],
    );
    final bookmarkIds = await database.customSelect(
      'SELECT id FROM bookmarks ORDER BY id',
    ).get();
    for (final row in bookmarkIds) {
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object>[row.read<int>('id'), workspaceId],
      );
    }

    await sync.syncWorkspace(workspaceId);

    final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    final weblinks = await sync.objectStore.listObjects(weblinkType.id);
    expect(weblinks, hasLength(1));
    final weblink = weblinks.single;
    final domain = weblinkType.properties.singleWhere(
      (property) => property.name == 'Domain',
    );
    final pageTitle = weblinkType.properties.singleWhere(
      (property) => property.name == 'Page title',
    );
    final description = weblinkType.properties.singleWhere(
      (property) => property.name == 'Description',
    );
    final preview = weblinkType.properties.singleWhere(
      (property) => property.name == 'Preview image URL',
    );

    expect(weblink.values[domain.id], 'example.com');
    expect(weblink.values[pageTitle.id], 'First resource title');
    expect(weblink.values[description.id], 'First resource description');
    expect(
      weblink.values[preview.id],
      'https://cdn.example.com/preview.jpg?sig=1',
    );

    await database.customStatement(
      '''UPDATE bookmarks
         SET title = ?, description = ?, thumbnail = ?''',
      <Object>[
        'Later bookmark-specific title',
        'Later bookmark-specific description',
        'https://cdn.example.com/later.jpg',
      ],
    );
    await sync.syncWorkspace(workspaceId);

    final preserved = (await sync.objectStore.listObjects(weblinkType.id)).single;
    expect(preserved.values[pageTitle.id], 'First resource title');
    expect(preserved.values[description.id], 'First resource description');
    expect(
      preserved.values[preview.id],
      'https://cdn.example.com/preview.jpg?sig=1',
    );
  });
}
