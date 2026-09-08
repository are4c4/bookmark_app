import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_stage1_image_drop_import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test(
    'Stage1 drop creates canonical Image only and ignores non-Image files',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceStore = WorkspaceStore(database);
      final workspaceId = await workspaceStore.initialize();
      final tempDirectory =
          await Directory.systemTemp.createTemp('stage1_image_drop_');
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final managedDirectory = Directory('${tempDirectory.path}/managed');
      final source = File('${tempDirectory.path}/misleading.pdf');
      await source.writeAsBytes(
        image.encodePng(image.Image(width: 2, height: 3)),
      );
      final ordinaryPdf = File('${tempDirectory.path}/ordinary.pdf');
      await ordinaryPdf.writeAsString('%PDF-1.7\nnot an image');

      final service = BookmarkStage1ImageDropImportService(
        workspaceStore: workspaceStore,
        workspaceId: workspaceId,
        photoDirectoryPath: managedDirectory.path,
      );
      final ids = await service.importDroppedPaths(
        <String>[
          source.path,
          ordinaryPdf.path,
          '${tempDirectory.path}/missing.png',
        ],
      );

      expect(ids, hasLength(1));
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final images = ImageObjectService(
        systemObjects: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      final definition = await images.ensureDefinition(workspaceId);
      final objects = await objectStore.listObjects(definition.objectType.id);
      expect(objects, hasLength(1));
      expect(objects.single.id, ids.single);
      expect(
        objects.single.values[definition.originalFilenameProperty.id],
        'misleading.pdf',
      );
      expect(
        objects.single.values[definition.contentTypeProperty.id],
        'image/png',
      );
      expect(objects.single.values[definition.pixelWidthProperty.id], 2);
      expect(objects.single.values[definition.pixelHeightProperty.id], 3);
      final managedPath =
          '${objects.single.values[definition.fileProperty.id]}';
      expect(managedPath, startsWith(managedDirectory.path));
      expect(managedPath, endsWith('.png'));
      expect(await File(managedPath).exists(), isTrue);

      final photoCount = (await database.customSelect(
        'SELECT COUNT(*) AS count FROM photos',
      ).getSingle())
          .read<int>('count');
      expect(photoCount, 0);

      expect(
        await service.importDroppedPaths(<String>[source.path]),
        <int>[ids.single],
      );
      expect(
        await objectStore.listObjects(definition.objectType.id),
        hasLength(1),
      );
    },
  );
}
