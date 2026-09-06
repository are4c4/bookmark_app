import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_alias.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alias normalization trims and collapses whitespace deterministically', () {
    expect(cleanObjectAlias('  Natsume   Soseki  '), 'Natsume Soseki');
    expect(normalizeObjectAlias('  Natsume   Soseki  '), 'natsume soseki');
    expect(
      canonicalizeObjectAliases([
        ' 漱石 ',
        'Natsume   Soseki',
        'natsume soseki',
        ' ',
        '夏目金之助',
      ]),
      ['漱石', 'Natsume Soseki', '夏目金之助'],
    );
  });

  test('Object aliases preserve order and de-duplicate within one Object', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final aliasStore = ObjectAliasStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Author',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: '夏目漱石',
    );

    await aliasStore.replaceAliases(
      objectId: objectId,
      aliases: ['夏目金之助', ' 漱石 ', 'SOSEKI', 'soseki'],
    );

    expect(
      await aliasStore.listAliases(objectId),
      ['夏目金之助', '漱石', 'SOSEKI'],
    );
    expect(
      (await aliasStore.listEntries(objectId)).map((entry) => entry.position),
      [0, 1, 2],
    );

    expect(
      await aliasStore.addAlias(objectId: objectId, alias: ' natsume  soseki '),
      isTrue,
    );
    expect(
      await aliasStore.addAlias(objectId: objectId, alias: 'NATSUME SOSEKI'),
      isFalse,
    );

    await aliasStore.removeAlias(objectId: objectId, alias: '漱石');
    expect(
      await aliasStore.listAliases(objectId),
      ['夏目金之助', 'SOSEKI', 'natsume soseki'],
    );
    expect(
      (await aliasStore.listEntries(objectId)).map((entry) => entry.position),
      [0, 1, 2],
    );
  });

  test('same alias can belong to multiple Objects and canonical rename is independent',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final aliasStore = ObjectAliasStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final firstId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'First',
    );
    final secondId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Second',
    );

    await aliasStore.addAlias(objectId: firstId, alias: 'shared');
    await aliasStore.addAlias(objectId: secondId, alias: 'shared');
    await objectStore.renameObject(firstId, 'Renamed First');

    expect(await aliasStore.listAliases(firstId), ['shared']);
    expect(await aliasStore.listAliases(secondId), ['shared']);
    expect(
      (await objectStore.listObjects(typeId))
          .singleWhere((object) => object.id == firstId)
          .title,
      'Renamed First',
    );
  });

  test('alias mutations advance Object freshness only when identity changes',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final aliasStore = ObjectAliasStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Canonical',
    );

    await _setOldFreshness(database, objectId);
    expect(await aliasStore.addAlias(objectId: objectId, alias: 'Alpha'), isTrue);
    expect(await _updatedYear(objectStore, typeId, objectId), isNot(2000));

    await _setOldFreshness(database, objectId);
    expect(await aliasStore.addAlias(objectId: objectId, alias: 'ALPHA'), isFalse);
    expect(await _updatedYear(objectStore, typeId, objectId), 2000);

    await aliasStore.replaceAliases(objectId: objectId, aliases: ['Alpha']);
    expect(await _updatedYear(objectStore, typeId, objectId), 2000);

    await aliasStore.replaceAliases(
      objectId: objectId,
      aliases: ['Alpha', 'Beta'],
    );
    expect(await _updatedYear(objectStore, typeId, objectId), isNot(2000));

    await _setOldFreshness(database, objectId);
    await aliasStore.removeAlias(objectId: objectId, alias: 'Missing');
    expect(await _updatedYear(objectStore, typeId, objectId), 2000);

    await aliasStore.removeAlias(objectId: objectId, alias: 'Alpha');
    expect(await aliasStore.listAliases(objectId), ['Beta']);
    expect(await _updatedYear(objectStore, typeId, objectId), isNot(2000));

    await _setOldFreshness(database, objectId);
    await aliasStore.clear(objectId);
    expect(await aliasStore.listAliases(objectId), isEmpty);
    expect(await _updatedYear(objectStore, typeId, objectId), isNot(2000));

    await _setOldFreshness(database, objectId);
    await aliasStore.clear(objectId);
    expect(await _updatedYear(objectStore, typeId, objectId), 2000);
  });

  test('alias removal rolls back when Object freshness update fails', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final aliasStore = ObjectAliasStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Protected',
    );
    await aliasStore.replaceAliases(
      objectId: objectId,
      aliases: ['First', 'Second'],
    );
    await database.customStatement('''
      CREATE TRIGGER fail_alias_parent_freshness_update
      BEFORE UPDATE OF updated_at ON generic_records
      WHEN OLD.id = $objectId
      BEGIN
        SELECT RAISE(ABORT, 'forced parent freshness failure');
      END
    ''');

    await expectLater(
      aliasStore.removeAlias(objectId: objectId, alias: 'First'),
      throwsA(anything),
    );

    expect(await aliasStore.listAliases(objectId), ['First', 'Second']);
    expect(
      (await aliasStore.listEntries(objectId)).map((entry) => entry.position),
      [0, 1],
    );
  });

  test('deleting Object cascades alias rows', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final aliasStore = ObjectAliasStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Temporary',
    );
    await aliasStore.addAlias(objectId: objectId, alias: 'Temp');

    await objectStore.deleteObject(objectId);

    final rows = await database.customSelect(
      'SELECT object_id FROM object_aliases',
    ).get();
    expect(rows, isEmpty);
  });
}

Future<void> _setOldFreshness(AppDatabase database, int objectId) async {
  await database.customStatement(
    "UPDATE generic_records SET updated_at = '2000-01-01 00:00:00' WHERE id = ?",
    [objectId],
  );
}

Future<int> _updatedYear(
  ObjectStore objectStore,
  int objectTypeId,
  int objectId,
) async =>
    (await objectStore.listObjects(objectTypeId))
        .singleWhere((object) => object.id == objectId)
        .updatedAt
        .year;
