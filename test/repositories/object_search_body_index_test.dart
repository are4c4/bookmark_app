import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Body text uses canonical Object index and focused refresh removes stale tokens',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final bodyStore = ObjectBodyStore(genericStore);
      final search = ObjectSearchRepository(genericStore);

      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Knowledge item',
      );
      final focused = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Focused object',
      );
      final unrelated = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Unrelated object',
      );
      await bodyStore.write(
        objectId: focused,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'StructuralTokenMustStayOpaque',
              type: 'futureRichBlock',
              text: 'LegacyBodyToken',
              attributes: <String, dynamic>{'objectId': 987654},
            ),
          ],
        ),
      );
      await bodyStore.write(
        objectId: unrelated,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'unrelated-body',
              type: 'paragraph',
              text: 'UnrelatedBodyToken',
            ),
          ],
        ),
      );

      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'legacybody'))
            .map((hit) => hit.objectId),
        contains(focused),
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'structuraltokenmuststayopaque',
        ),
        isEmpty,
        reason: 'Body structural ids must not leak into the search projection',
      );

      await bodyStore.write(
        objectId: focused,
        document: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'current-body',
              type: 'paragraph',
              text: 'CurrentBodyToken',
            ),
          ],
        ),
      );
      await search.refreshObject(focused);

      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'currentbody'))
            .map((hit) => hit.objectId),
        contains(focused),
      );
      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'legacybody'))
            .map((hit) => hit.objectId),
        isNot(contains(focused)),
        reason: 'focused refresh must remove stale Body tokens',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'unrelatedbody',
        ))
            .map((hit) => hit.objectId),
        contains(unrelated),
        reason: 'focused refresh must leave unrelated Object rows intact',
      );

      await bodyStore.clear(focused);
      await search.refreshObject(focused);

      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'currentbody'))
            .map((hit) => hit.objectId),
        isNot(contains(focused)),
        reason: 'clearing Body content must clear its searchable tokens',
      );
    },
  );
}
