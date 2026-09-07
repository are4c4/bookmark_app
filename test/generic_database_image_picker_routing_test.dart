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
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

class _PickerPhotoStorageService extends PhotoStorageService {
  _PickerPhotoStorageService({
    required String photoDirectoryPath,
    required this.paths,
  }) : super(photoDirectoryPath: photoDirectoryPath);

  final List<String> paths;

  @override
  Future<List<String>> pickImagePaths() async => paths;
}

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late ImageObjectService images;
  late GenericDatabaseObjectCreateService objectCreate;
  late Directory root;
  late Directory managedDirectory;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    images = ImageObjectService(
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
    objectCreate = GenericDatabaseObjectCreateService(
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

    root = await Directory.systemTemp.createTemp('image_picker_routing_');
    managedDirectory = Directory('${root.path}/managed');
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  List<File> managedFiles() => managedDirectory.existsSync()
      ? managedDirectory.listSync().whereType<File>().toList()
      : const <File>[];

  test('picker imports PNG content even when source extension says PDF', () async {
    final source = File('${root.path}/misleading.pdf');
    await source.writeAsBytes(
      image.encodePng(image.Image(width: 3, height: 2)),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final importer = GenericDatabaseImageImportService(
      photoStorage: _PickerPhotoStorageService(
        photoDirectoryPath: managedDirectory.path,
        paths: <String>[source.path],
      ),
      objectCreate: objectCreate,
    );

    final ids = await importer.pickAndImport(
      databaseId: definition.objectType.id,
    );

    expect(ids, hasLength(1));
    final files = managedFiles();
    expect(files, hasLength(1));
    expect(files.single.path.toLowerCase(), endsWith('.png'));

    final stored = (await objectStore.listObjects(definition.objectType.id)).single;
    expect(stored.id, ids.single);
    expect(stored.values[definition.originalFilenameProperty.id], 'misleading.pdf');
    expect(stored.values[definition.contentTypeProperty.id], 'image/png');
    expect(stored.values[definition.pixelWidthProperty.id], 3);
    expect(stored.values[definition.pixelHeightProperty.id], 2);
  });

  test('mixed Image and File picker selection fails before any mutation', () async {
    final png = File('${root.path}/first.png');
    await png.writeAsBytes(
      image.encodePng(image.Image(width: 2, height: 1)),
    );
    final pdf = File('${root.path}/second.pdf');
    await pdf.writeAsBytes('%PDF-1.7\nbody'.codeUnits);
    final definition = await images.ensureDefinition(workspaceId);
    final importer = GenericDatabaseImageImportService(
      photoStorage: _PickerPhotoStorageService(
        photoDirectoryPath: managedDirectory.path,
        paths: <String>[png.path, pdf.path],
      ),
      objectCreate: objectCreate,
    );

    await expectLater(
      importer.pickAndImport(databaseId: definition.objectType.id),
      throwsA(isA<GenericDatabaseImageImportRequiresFileException>()),
    );

    expect(managedFiles(), isEmpty);
    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
  });
}
