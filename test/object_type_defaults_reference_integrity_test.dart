import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ObjectType defaults accept owned Property refs and body-only defaults',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Valid defaults',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Summary',
      type: ObjectPropertyType.text,
    );

    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId],
        propertyOrder: <int>[propertyId],
        bodyTemplate: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'template',
              type: 'paragraph',
              text: 'Start here',
            ),
          ],
        ),
      ),
    );

    var stored = await defaultsStore.read(typeId);
    expect(stored?.visiblePropertyIds, <int>[propertyId]);
    expect(stored?.propertyOrder, <int>[propertyId]);
    expect(stored?.bodyTemplate?.blocks.single.text, 'Start here');

    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[],
        propertyOrder: <int>[],
        bodyTemplate: ObjectBodyDocument(),
      ),
    );

    stored = await defaultsStore.read(typeId);
    expect(stored?.visiblePropertyIds, isEmpty);
    expect(stored?.propertyOrder, isEmpty);
    expect(stored?.bodyTemplate?.isEmpty, isTrue);
  });

  test('ObjectType defaults reject cross-type refs without replacing current row',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final sourcePropertyId = await objectStore.createProperty(
      objectTypeId: sourceId,
      name: 'Owned',
      type: ObjectPropertyType.text,
    );
    final otherId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Other',
    );
    final otherPropertyId = await objectStore.createProperty(
      objectTypeId: otherId,
      name: 'Foreign',
      type: ObjectPropertyType.text,
    );

    await defaultsStore.write(
      objectTypeId: sourceId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[sourcePropertyId],
        propertyOrder: <int>[sourcePropertyId],
        openMode: ObjectOpenMode.centerPeek,
      ),
    );

    await expectLater(
      defaultsStore.write(
        objectTypeId: sourceId,
        defaults: ObjectTypeDefaults(
          visiblePropertyIds: <int>[otherPropertyId],
          propertyOrder: <int>[sourcePropertyId, otherPropertyId],
          openMode: ObjectOpenMode.fullPage,
        ),
      ),
      throwsArgumentError,
    );

    final stored = await defaultsStore.read(sourceId);
    expect(stored?.visiblePropertyIds, <int>[sourcePropertyId]);
    expect(stored?.propertyOrder, <int>[sourcePropertyId]);
    expect(stored?.openMode, ObjectOpenMode.centerPeek);
  });

  test('ObjectType defaults reject missing Property refs and missing ObjectTypes',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Missing refs',
    );

    await expectLater(
      defaultsStore.write(
        objectTypeId: typeId,
        defaults: const ObjectTypeDefaults(propertyOrder: <int>[999999]),
      ),
      throwsArgumentError,
    );
    expect(await defaultsStore.read(typeId), isNull);

    await expectLater(
      defaultsStore.write(
        objectTypeId: 999999,
        defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.fullPage),
      ),
      throwsArgumentError,
    );
  });
}
