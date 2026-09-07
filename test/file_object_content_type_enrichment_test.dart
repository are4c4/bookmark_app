import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid File MIME stays missing so a valid reimport can enrich it',
      () async {
    final root = await Directory.systemTemp.createTemp('file_mime_enrichment_');
    addTearDown(() => root.delete(recursive: true));
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);
    const malformedValues = <String>[
      'not-a-mime',
      'application/',
      '/pdf',
      'application/pdf/extra',
      'application / pdf',
    ];

    for (var index = 0; index < malformedValues.length; index++) {
      final filename = 'report-$index.pdf';
      final first = await service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '${root.path}/files/$filename',
        contentType: malformedValues[index],
      );

      expect(
        first.values[definition.contentTypeProperty.id],
        isNull,
        reason: malformedValues[index],
      );

      final enriched = await service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: 'files/$filename',
        contentType: ' Application/PDF; charset=UTF-8 ',
      );

      expect(enriched.id, first.id, reason: malformedValues[index]);
      expect(
        enriched.values[definition.contentTypeProperty.id],
        'application/pdf',
        reason: malformedValues[index],
      );
    }
  });
}
