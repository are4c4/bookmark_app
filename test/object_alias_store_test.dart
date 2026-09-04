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
