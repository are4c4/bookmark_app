import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_duplicate_advisory_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_duplicate_candidate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late ObjectAliasStore aliasStore;
  late ObjectDuplicateAdvisoryService service;
  late int workspaceId;
  late int personTypeId;
  late int bookTypeId;
  late int aliceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    aliasStore = ObjectAliasStore(genericStore);
    service = ObjectDuplicateAdvisoryService(
      objectStore: objectStore,
      aliasStore: aliasStore,
    );

    personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    aliceId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Alice Smith',
    );
    await aliasStore.replaceAliases(
      objectId: aliceId,
      aliases: <String>['Ally', 'A. Smith'],
    );
    await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Bob Stone',
    );
    await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Alice Smith',
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('exact normalized canonical title is an advisory candidate', () async {
    final candidates = await service.findCandidates(
      objectTypeId: personTypeId,
      title: '  ALICE   SMITH ',
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.objectId, aliceId);
    expect(candidates.single.canonicalTitle, 'Alice Smith');
    expect(candidates.single.matches, hasLength(1));
    expect(
      candidates.single.matches.single.proposedKind,
      ObjectDuplicateIdentityKind.canonicalTitle,
    );
    expect(
      candidates.single.matches.single.existingKind,
      ObjectDuplicateIdentityKind.canonicalTitle,
    );
  });

  test('proposed alias can match existing canonical title or alias', () async {
    final candidates = await service.findCandidates(
      objectTypeId: personTypeId,
      title: 'New Person',
      aliases: <String>[' ally ', 'ALICE  SMITH'],
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.objectId, aliceId);
    expect(
      candidates.single.matches.map((match) => match.existingKind),
      <ObjectDuplicateIdentityKind>[
        ObjectDuplicateIdentityKind.canonicalTitle,
        ObjectDuplicateIdentityKind.alias,
      ],
    );
  });

  test(
    'multiple matching terms still produce one deterministic candidate',
    () async {
      final secondId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'Ally',
      );

      final candidates = await service.findCandidates(
        objectTypeId: personTypeId,
        title: 'alice smith',
        aliases: <String>['ALLY', 'A. Smith', 'ally'],
      );

      expect(candidates.map((candidate) => candidate.objectId), <int>[
        aliceId,
        secondId,
      ]);
      expect(candidates.first.matches.length, 3);
      expect(candidates.last.matches, hasLength(1));
    },
  );

  test(
    'different ObjectTypes and excluded current Object are not reported',
    () async {
      expect(
        await service.findCandidates(
          objectTypeId: personTypeId,
          title: 'Alice Smith',
          excludingObjectId: aliceId,
        ),
        isEmpty,
      );

      final bookCandidates = await service.findCandidates(
        objectTypeId: bookTypeId,
        title: 'Alice Smith',
      );
      expect(bookCandidates, hasLength(1));
      expect(bookCandidates.single.objectTypeId, bookTypeId);
    },
  );

  test(
    'partial and fuzzy-looking similarity alone is not a candidate',
    () async {
      expect(
        await service.findCandidates(
          objectTypeId: personTypeId,
          title: 'Alice',
        ),
        isEmpty,
      );
      expect(
        await service.findCandidates(
          objectTypeId: personTypeId,
          title: 'Alic Smth',
        ),
        isEmpty,
      );
    },
  );

  test('candidate detection is read-only', () async {
    final beforeObjects = await objectStore.listObjects(personTypeId);
    final beforeAliases = await aliasStore.listAliases(aliceId);

    await service.findCandidates(
      objectTypeId: personTypeId,
      title: 'Alice Smith',
      aliases: <String>['Ally'],
    );

    final afterObjects = await objectStore.listObjects(personTypeId);
    final afterAliases = await aliasStore.listAliases(aliceId);
    expect(
      afterObjects.map((object) => object.id),
      beforeObjects.map((object) => object.id),
    );
    expect(afterAliases, beforeAliases);
  });

  test('malformed ObjectType and exclusion ids fail closed', () async {
    await expectLater(
      service.findCandidates(objectTypeId: 0, title: 'Alice'),
      throwsArgumentError,
    );
    await expectLater(
      service.findCandidates(objectTypeId: 999999, title: 'Alice'),
      throwsArgumentError,
    );
    await expectLater(
      service.findCandidates(
        objectTypeId: personTypeId,
        title: 'Alice',
        excludingObjectId: 0,
      ),
      throwsArgumentError,
    );
  });
}
