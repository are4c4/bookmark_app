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
  late int workspaceId;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('file_picker_vault_');
    sources = await Directory.systemTemp.createTemp('file_picker_sources_');
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
  });

  tearDown(() async {
    await database.close();
    await vault.delete(recursive: true);
    await sources.delete(recursive: true);
  });

  GenericDatabaseFileImportService importerFor(List<String> picked) =>
      GenericDatabaseFileImportService(
        managedFiles: VaultManagedFileCopyService(),
        objectCreate: objectCreate,
        vaultDirectoryPath: vault.path,
        filePicker: () async => picked,
      );

  test('picker uses content-first File classification before managed copy',
      () async {
    final source = File('${sources.path}/paper.png');
    await source.writeAsBytes('%PDF-1.7\nbody'.codeUnits);
    final definition = await files.ensureDefinition(workspaceId);

    final ids = await importerFor(<String>[source.path]).pickAndImport(
      databaseId: definition.objectType.id,
    );

    expect(ids, hasLength(1));
    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.id, ids.single);
    expect(
      objects.single.values[definition.contentTypeProperty.id],
      'application/pdf',
    );
    expect(
      objects.single.values[definition.originalFilenameProperty.id],
      'paper.png',
    );
    expect(await source.exists(), isTrue);
  });

  test('mixed picker selection rejects Image before any File side effect',
      () async {
    final notes = File('${sources.path}/notes.txt');
    await notes.writeAsString('notes');
    final image = File('${sources.path}/photo.bin');
    await image.writeAsBytes(const <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
    ]);
    final definition = await files.ensureDefinition(workspaceId);

    await expectLater(
      importerFor(<String>[notes.path, image.path]).pickAndImport(
        databaseId: definition.objectType.id,
      ),
      throwsA(isA<GenericDatabaseFileImportRequiresImageException>()),
    );

    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
    final attachments = Directory('${vault.path}/attachments');
    expect(await attachments.exists(), isFalse);
    expect(await notes.exists(), isTrue);
    expect(await image.exists(), isTrue);
  });

  test('unavailable picker source fails before copy without exposing path',
      () async {
    final missing = '${sources.path}/private/missing.txt';
    final definition = await files.ensureDefinition(workspaceId);
    Object? failure;

    try {
      await importerFor(<String>[missing]).pickAndImport(
        databaseId: definition.objectType.id,
      );
    } catch (error) {
      failure = error;
    }

    expect(failure, isA<GenericDatabaseFileImportSourceUnavailableException>());
    expect('$failure', isNot(contains(missing)));
    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
    expect(await Directory('${vault.path}/attachments').exists(), isFalse);
  });
}
