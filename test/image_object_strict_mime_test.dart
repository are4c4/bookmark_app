import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('malformed Image MIME stays missing until valid reimport enrichment',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    const malformedValues = <String>[
      'image/',
      '/png',
      'image/png/extra',
      'image / png',
    ];

    for (var index = 0; index < malformedValues.length; index++) {
      final path = '/managed/mime-$index.png';
      final first = await service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: path,
        contentType: malformedValues[index],
      );

      var stored = (await objectStore.listObjects(definition.objectType.id))
          .singleWhere((object) => object.id == first.id);
      expect(
        stored.values[definition.contentTypeProperty.id],
        isNull,
        reason: malformedValues[index],
      );

      final enriched = await service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: ' $path ',
        contentType: ' Image/PNG; charset=binary ',
      );
      stored = (await objectStore.listObjects(definition.objectType.id))
          .singleWhere((object) => object.id == first.id);

      expect(enriched.id, first.id, reason: malformedValues[index]);
      expect(
        stored.values[definition.contentTypeProperty.id],
        'image/png',
        reason: malformedValues[index],
      );
    }
  });
}
