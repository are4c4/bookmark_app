import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('malformed Weblink MIME stays missing until valid enrichment', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    const malformedValues = <String>[
      'text/',
      '/html',
      'text/html/extra',
      'text / html',
    ];

    for (var index = 0; index < malformedValues.length; index++) {
      final weblink = await service.findOrCreate(
        workspaceId: workspaceId,
        url: 'https://example.net/article-$index',
      );

      final invalid = await service.enrichIfMissing(
        workspaceId: workspaceId,
        objectId: weblink.id,
        contentType: malformedValues[index],
      );
      expect(
        invalid.values[definition.contentTypeProperty.id],
        isNull,
        reason: malformedValues[index],
      );

      final enriched = await service.enrichIfMissing(
        workspaceId: workspaceId,
        objectId: weblink.id,
        contentType: ' Text/HTML; charset=UTF-8 ',
      );
      expect(enriched.id, weblink.id, reason: malformedValues[index]);
      expect(
        enriched.values[definition.contentTypeProperty.id],
        'text/html',
        reason: malformedValues[index],
      );
    }
  });
}
