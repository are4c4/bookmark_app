import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'typed Properties use canonical Object index and focused refresh removes stale tokens',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final search = ObjectSearchRepository(genericStore);

      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Knowledge item',
      );
      final summaryId = await objectStore.createProperty(
        objectTypeId: typeId,
        name: 'Summary',
        type: ObjectPropertyType.text,
      );
      final topicsId = await objectStore.createProperty(
        objectTypeId: typeId,
        name: 'Topics',
        type: ObjectPropertyType.multiSelect,
      );
      final fileId = await objectStore.createProperty(
        objectTypeId: typeId,
        name: 'Attachment',
        type: ObjectPropertyType.file,
      );
      final hiddenId = await objectStore.createProperty(
        objectTypeId: typeId,
        name: 'Private metadata',
        type: ObjectPropertyType.text,
        config: const <String, dynamic>{'searchable': false},
      );
      final objectType = (await objectStore.getObjectType(typeId))!;
      ObjectPropertyDefinition propertyById(int id) =>
          objectType.properties.firstWhere((property) => property.id == id);

      final focused = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Focused object',
      );
      final unrelated = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Unrelated object',
      );
      await objectStore.setPropertyValue(
        objectId: focused,
        property: propertyById(summaryId),
        value: 'LegacyPropertyToken',
      );
      await objectStore.setPropertyValue(
        objectId: focused,
        property: propertyById(topicsId),
        value: const <String>['FlutterTopicToken', 'SQLiteTopicToken'],
      );
      await objectStore.setPropertyValue(
        objectId: focused,
        property: propertyById(fileId),
        value: '/private/SecretFileIdentityToken.bin',
      );
      await objectStore.setPropertyValue(
        objectId: focused,
        property: propertyById(hiddenId),
        value: 'PrivatePropertyToken',
      );
      await objectStore.setPropertyValue(
        objectId: unrelated,
        property: propertyById(summaryId),
        value: 'UnrelatedPropertyToken',
      );

      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'legacyproperty'))
            .map((hit) => hit.objectId),
        contains(focused),
      );
      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'fluttertopic'))
            .map((hit) => hit.objectId),
        contains(focused),
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'secretfileidentitytoken',
        ),
        isEmpty,
        reason: 'File identity values must not leak into typed Property search',
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'privateproperty',
        ),
        isEmpty,
        reason: 'searchable false must opt the Property out',
      );

      await objectStore.setPropertyValue(
        objectId: focused,
        property: propertyById(summaryId),
        value: 'CurrentPropertyToken',
      );
      await search.refreshObject(focused);

      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'currentproperty'))
            .map((hit) => hit.objectId),
        contains(focused),
      );
      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'legacyproperty'))
            .map((hit) => hit.objectId),
        isNot(contains(focused)),
        reason: 'focused refresh must remove stale Property tokens',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'unrelatedproperty',
        ))
            .map((hit) => hit.objectId),
        contains(unrelated),
        reason: 'focused refresh must leave unrelated Object rows intact',
      );

      await objectStore.setPropertyValue(
        objectId: focused,
        property: propertyById(summaryId),
        value: null,
      );
      await search.refreshObject(focused);
      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: 'currentproperty'))
            .map((hit) => hit.objectId),
        isNot(contains(focused)),
        reason: 'removing a typed Property value must remove its search tokens',
      );
    },
  );
}
