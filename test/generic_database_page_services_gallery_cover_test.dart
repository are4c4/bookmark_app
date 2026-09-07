import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('page services expose canonical Gallery cover discovery', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Plant',
      icon: '🪴',
    );
    final coverPropertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Photo',
      targetObjectTypeId: imageType.id,
      multiple: false,
    );

    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final options = await services.galleryCoverSources.discover(
      objectTypeId: sourceTypeId,
    );

    expect(
      options.map((option) => option.source),
      [
        const GalleryCoverSource.none(),
        GalleryCoverSource.imageRelation(coverPropertyId),
      ],
    );
    expect(options.map((option) => option.label), ['なし', 'Photo · Image']);
  });
}
