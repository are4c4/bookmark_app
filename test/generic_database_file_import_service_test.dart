import 'dart:io';

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
import 'package:bookmark_app/services/generic_database_file_import_service.dart';
import 'package:bookmark_app/services/primitive_file_import_classifier.dart';
import 'package:bookmark_app/services/primitive_object_import_service.dart';
import 'package:bookmark_app/services/vault_managed_file_copy_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory vault;
  late Directory sources;
  late AppDatabase database;
  late ObjectStore objectStore;
  late FileObjectService files;
  late GenericDatabaseObjectCreateService objectCreate;
  late GenericDatabaseFileImportService fileImports;
  late int workspaceId;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('generic_file_import_vault_');
    sources = await Directory.systemTemp.createTemp('generic_file_import_source_');
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: vault.path,
    );
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
      files: files,
    );
    fileImports = GenericDatabaseFileImportService(
      managedFiles: VaultManagedFileCopyService(),
      objectCreate: objectCreate,
      vaultDirectoryPath: vault.path,
    );
  });

  tearDown(() async {
    await database.close();
    await vault.delete(recursive: true);
    await sources.delete(recursive: true);
  });

  test('content-first router imports arbitrary source as one managed File',
      () async {
    final source = File('${sources.path}/paper.png');
    await source.writeAsBytes('%PDF-1.7\nbody'.codeUnits);
    final definition = await files.ensureDefinition(workspaceId);
    var imageCalls = 0;
    final router = PrimitiveObjectImportService(
      importImage: ({
        required int databaseId,
        required String sourcePath,
        String? contentType,
      }) async {
        imageCalls++;
        return 999;
      },
      importFile: ({
        required int databaseId,
        required String sourcePath,
        String? contentType,
      }) =>
          fileImports.importClassifiedPath(
        databaseId: databaseId,
        sourcePath: sourcePath,
        contentType: contentType,
      ),
    );

    final result = await router.importPath(
      databaseId: definition.objectType.id,
      sourcePath: source.path,
      declaredContentType: 'image/png',
    );

    expect(result.target, PrimitiveFileImportTarget.file);
    expect(result.evidence, PrimitiveFileImportEvidence.content);
    expect(result.contentType, 'application/pdf');
    expect(imageCalls, 0);
    expect(await source.exists(), isTrue);

    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.id, result.objectId);
    expect(
      objects.single.values[definition.originalFilenameProperty.id],
      'paper.png',
    );
    expect(
      objects.single.values[definition.contentTypeProperty.id],
      'application/pdf',
    );
    expect(
      objects.single.values[definition.sizeBytesProperty.id],
      await source.length(),
    );
    expect(
      objects.single.values[definition.sha256Property.id],
      '3f972854841afd236b04b5d7435b73216bc5fa6e39a86aff6e492b744086189c',
    );
    expect(
      objects.single.values[definition.storageOwnershipProperty.id],
      VaultManagedFileOwnership.vaultManagedCopy.storageKey,
    );
    final storedPath = objects.single.values[definition.fileProperty.id] as String;
    expect(storedPath, startsWith('attachments/'));
    expect(await File('${vault.path}/$storedPath').exists(), isTrue);
  });

  test('SHA-256 probe failure does not fail an otherwise valid File import',
      () async {
    final source = File('${sources.path}/notes.txt');
    await source.writeAsString('portable notes');
    final definition = await files.ensureDefinition(workspaceId);
    final failSoftImports = GenericDatabaseFileImportService(
      managedFiles: VaultManagedFileCopyService(),
      objectCreate: objectCreate,
      vaultDirectoryPath: vault.path,
      sha256Reader: (_) async => throw StateError('hash unavailable'),
    );

    final objectId = await failSoftImports.importClassifiedPath(
      databaseId: definition.objectType.id,
      sourcePath: source.path,
      contentType: 'text/plain',
    );

    final object = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((candidate) => candidate.id == objectId);
    expect(object.values[definition.sha256Property.id], isNull);
    expect(
      object.values[definition.storageOwnershipProperty.id],
      VaultManagedFileOwnership.vaultManagedCopy.storageKey,
    );
    final storedPath = object.values[definition.fileProperty.id] as String;
    expect(await File('${vault.path}/$storedPath').exists(), isTrue);
    expect(await source.exists(), isTrue);
  });

  test('File Object failure rolls back only the new Vault copy', () async {
    final source = File('${sources.path}/archive.bin');
    await source.writeAsBytes(<int>[1, 2, 3, 4]);
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Not File',
    );

    await expectLater(
      fileImports.importClassifiedPath(
        databaseId: customTypeId,
        sourcePath: source.path,
        contentType: 'application/octet-stream',
      ),
      throwsA(isA<UnsupportedError>()),
    );

    expect(await source.exists(), isTrue);
    final attachments = Directory('${vault.path}/attachments');
    expect(await attachments.exists(), isTrue);
    expect(await attachments.list().toList(), isEmpty);
    expect(await objectStore.listObjects(customTypeId), isEmpty);
  });
}
