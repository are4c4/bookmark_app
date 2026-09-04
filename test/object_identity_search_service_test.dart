import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_identity_search_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late ObjectAliasStore aliasStore;
  late ObjectIdentitySearchService service;
  late int workspaceId;
  late int peopleTypeId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    aliasStore = ObjectAliasStore(genericStore);
    service = ObjectIdentitySearchService(
      objectStore: objectStore,
      aliasStore: aliasStore,
    );
    peopleTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
  });

  test('canonical and alias lookup resolve the same Object id', () async {
    final objectId = await objectStore.createObject(
      objectTypeId: peopleTypeId,
      title: '夏目漱石',
    );
    await aliasStore.replaceAliases(
      objectId: objectId,
      aliases: const ['夏目金之助', 'Natsume Soseki', '漱石'],
    );

    final canonical = await service.search(
      workspaceId: workspaceId,
      query: '夏目漱石',
    );
    final alias = await service.search(
      workspaceId: workspaceId,
      query: 'natsume',
    );

    expect(canonical.single.objectId, objectId);
    expect(canonical.single.canonicalTitle, '夏目漱石');
    expect(canonical.single.matchedAlias, isNull);
    expect(alias.single.objectId, objectId);
    expect(alias.single.canonicalTitle, '夏目漱石');
    expect(alias.single.matchedAlias, 'Natsume Soseki');
    expect(alias.single.aliasContext, '別名: Natsume Soseki');
  });

  test('ambiguous alias returns every canonical Object identity', () async {
    final first = await objectStore.createObject(
      objectTypeId: peopleTypeId,
      title: 'Alice A',
    );
    final second = await objectStore.createObject(
      objectTypeId: peopleTypeId,
      title: 'Alice B',
    );
    await aliasStore.addAlias(objectId: first, alias: 'Alice');
    await aliasStore.addAlias(objectId: second, alias: 'Alice');

    final results = await service.search(
      workspaceId: workspaceId,
      query: 'alice',
    );

    expect(results.map((result) => result.objectId).toSet(), {first, second});
    expect(results.every((result) => result.matchedAlias == 'Alice'), isTrue);
  });

  test('ObjectType scope and workspace scope are enforced', () async {
    final person = await objectStore.createObject(
      objectTypeId: peopleTypeId,
      title: 'Canonical Person',
    );
    await aliasStore.addAlias(objectId: person, alias: 'Shared alias');

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final book = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Canonical Book',
    );
    await aliasStore.addAlias(objectId: book, alias: 'Shared alias');

    final personOnly = await service.search(
      workspaceId: workspaceId,
      objectTypeId: peopleTypeId,
      query: 'shared',
    );
    expect(personOnly.map((result) => result.objectId), [person]);

    final otherWorkspace = await database.into(database.workspaces).insert(
      WorkspacesCompanion.insert(name: 'Other'),
    );
    final otherType = await objectStore.createObjectType(
      workspaceId: otherWorkspace,
      name: 'Person',
    );
    final otherObject = await objectStore.createObject(
      objectTypeId: otherType,
      title: 'Other',
    );
    await aliasStore.addAlias(objectId: otherObject, alias: 'Shared alias');

    final workspaceResults = await service.search(
      workspaceId: workspaceId,
      query: 'shared',
    );
    expect(
      workspaceResults.map((result) => result.objectId).toSet(),
      {person, book},
    );
  });

  test('blank query returns canonical Objects without inventing alias matches',
      () async {
    final objectId = await objectStore.createObject(
      objectTypeId: peopleTypeId,
      title: '夏目漱石',
    );
    await aliasStore.addAlias(objectId: objectId, alias: '漱石');

    final results = await service.search(
      workspaceId: workspaceId,
      query: '   ',
    );

    expect(results.single.objectId, objectId);
    expect(results.single.matchedAlias, isNull);
    expect(results.single.aliases, ['漱石']);
  });
}
