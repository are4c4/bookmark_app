import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Image metadata participates without exposing managed path',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final search = ObjectSearchRepository(genericStore);

    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'attachments/opaque-image-path-token.png',
      sourceUrl: 'https://images.example.com/source-search-token.png',
      title: 'Reference image',
      originalFilename: 'diagram-search-token.png',
      contentType: 'image/png',
      pixelWidth: 1440,
      pixelHeight: 900,
    );

    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'diagram'))
          .map((hit) => hit.objectId),
      contains(image.id),
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'source-search'))
          .map((hit) => hit.objectId),
      contains(image.id),
    );
    expect(
      (await search.search(workspaceId: workspaceId, rawQuery: 'image'))
          .map((hit) => hit.objectId),
      contains(image.id),
    );
    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'opaque-image-path-token',
      ),
      isEmpty,
      reason: 'managed Image file identity/path must stay out of free-text search',
    );
  });
}
