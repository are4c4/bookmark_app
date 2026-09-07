import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_collection_page_data.dart';
import 'package:bookmark_app/data/generic_database_object_create_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_board_create_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late FileObjectService files;
  late GenericDatabaseObjectCreateService service;
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
    files = FileObjectService(
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
    service = GenericDatabaseObjectCreateService(
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
      files: files,
    );
  });

  tearDown(() => database.close());

  test('managed File collection creation reuses canonical File identity', () async {
    final definition = await files.ensureDefinition(workspaceId);
    const sha256 =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    // Until the mixed file-import host lands, title-only generic creation must
    // fail closed rather than bypass canonical managed-file identity.
    await expectLater(
      service.create(
        databaseId: definition.objectType.id,
        title: 'Bypass',
      ),
      throwsA(isA<UnsupportedError>()),
    );

    final firstId = await service.createFileFromManagedFile(
      databaseId: definition.objectType.id,
      filePath: '/managed/report.pdf',
      title: 'Report',
      originalFilename: 'report.pdf',
      contentType: 'application/pdf',
      sizeBytes: 42,
      sha256: sha256,
      importedAt: DateTime.utc(2026, 9, 7),
    );
    final secondId = await service.createFileFromManagedFile(
      databaseId: definition.objectType.id,
      filePath: '/managed/report.pdf',
      title: 'Different title must not duplicate',
    );

    expect(secondId, firstId);
    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.title, 'Report');
    expect(objects.single.values[definition.fileProperty.id], '/managed/report.pdf');
    expect(
      objects.single.values[definition.originalFilenameProperty.id],
      'report.pdf',
    );
    expect(
      objects.single.values[definition.contentTypeProperty.id],
      'application/pdf',
    );
    expect(objects.single.values[definition.sizeBytesProperty.id], 42);
    expect(objects.single.values[definition.sha256Property.id], sha256);
  });

  test('managed File creation rejects a non-File collection before mutation',
      () async {
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Paper',
    );

    await expectLater(
      service.createFileFromManagedFile(
        databaseId: customTypeId,
        filePath: '/managed/paper.pdf',
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await objectStore.listObjects(customTypeId), isEmpty);
  });
}
