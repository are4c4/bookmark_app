import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/generic_database_image_import_service.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/primitive_file_import_classifier.dart';
import 'package:bookmark_app/services/primitive_object_import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('primitive router imports PNG content with misleading extension as Image',
      () async {
    final root = await Directory.systemTemp.createTemp('classified_image_');
    addTearDown(() => root.delete(recursive: true));
    final managedDirectory = Directory('${root.path}/managed');
    final source = File('${root.path}/paper.pdf');
    await source.writeAsBytes(
      image.encodePng(image.Image(width: 3, height: 2)),
    );

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    final objectCreate = GenericDatabaseObjectCreateService(
      pageLoader: GenericDatabaseCollectionPageLoader(
        genericStore: genericStore,
        collectionResolver: DatabaseCollectionResolver(
          collectionStore: collectionStore,
          objectStore: objectStore,
        ),
      ),
      objectStore: objectStore,
      boardCreate: ObjectBoardCreateService(
        objectStore,
        relationMutations: mutations,
      ),
      systemObjects: systemObjects,
      images: images,
    );
    final imageImport = GenericDatabaseImageImportService(
      photoStorage: PhotoStorageService(
        photoDirectoryPath: managedDirectory.path,
      ),
      objectCreate: objectCreate,
    );
    final definition = await images.ensureDefinition(workspaceId);
    var fileCalls = 0;
    final router = PrimitiveObjectImportService(
      importImage: ({
        required databaseId,
        required sourcePath,
        contentType,
      }) {
        if (contentType == null) {
          throw StateError('Image route requires a classified content type.');
        }
        return imageImport.importClassifiedPath(
          databaseId: databaseId,
          sourcePath: sourcePath,
          contentType: contentType,
        );
      },
      importFile: ({
        required databaseId,
        required sourcePath,
        contentType,
      }) async {
        fileCalls++;
        return 999;
      },
    );

    final first = await router.importPath(
      databaseId: definition.objectType.id,
      sourcePath: source.path,
      declaredContentType: 'application/pdf',
    );
    final second = await router.importPath(
      databaseId: definition.objectType.id,
      sourcePath: source.path,
      declaredContentType: 'application/pdf',
    );

    expect(first.target, PrimitiveFileImportTarget.image);
    expect(first.evidence, PrimitiveFileImportEvidence.content);
    expect(first.contentType, 'image/png');
    expect(second.objectId, first.objectId);
    expect(fileCalls, 0);

    final managedFiles = managedDirectory.listSync().whereType<File>().toList();
    expect(managedFiles, hasLength(1));
    expect(managedFiles.single.path.toLowerCase(), endsWith('.png'));

    final object = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((candidate) => candidate.id == first.objectId);
    expect(object.values[definition.originalFilenameProperty.id], 'paper.pdf');
    expect(object.values[definition.contentTypeProperty.id], 'image/png');
    expect(object.values[definition.pixelWidthProperty.id], 3);
    expect(object.values[definition.pixelHeightProperty.id], 2);
  });

  test('classified Image storage rejects unsupported content types', () async {
    final root = await Directory.systemTemp.createTemp('classified_image_mime_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/payload.bin');
    await source.writeAsBytes(const <int>[1, 2, 3]);
    final storage = PhotoStorageService(
      photoDirectoryPath: '${root.path}/managed',
    );

    await expectLater(
      storage.importClassifiedImagePath(
        sourcePath: source.path,
        contentType: 'application/pdf',
      ),
      throwsArgumentError,
    );
    expect(Directory('${root.path}/managed').existsSync(), isFalse);
  });
}
