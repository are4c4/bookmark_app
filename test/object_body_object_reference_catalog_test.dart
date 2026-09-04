import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_identity_search_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/object/presentation/object_body_object_reference_catalog.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog carries aliases while preserving canonical Object identity', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final aliasStore = ObjectAliasStore(genericStore);
    final peopleTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
      icon: '👤',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: peopleTypeId,
      title: 'Serre',
    );
    await aliasStore.replaceAliases(
      objectId: objectId,
      aliases: const <String>['ジャン＝ピエール・セール', 'J.-P. Serre'],
    );

    final catalog = ObjectBodyObjectReferenceCatalog(
      identitySearch: ObjectIdentitySearchService(
        objectStore: objectStore,
        aliasStore: aliasStore,
      ),
    );

    final candidates = await catalog.load(workspaceId: workspaceId);

    final candidate = candidates.single;
    expect(candidate.objectId, objectId);
    expect(candidate.title, 'Serre');
    expect(candidate.objectTypeName, 'Person');
    expect(candidate.objectTypeIcon, '👤');
    expect(
      candidate.aliases,
      const <String>['ジャン＝ピエール・セール', 'J.-P. Serre'],
    );
  });
}
