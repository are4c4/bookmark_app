import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('page composition exposes one canonical Property authoring and schema stack',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Paper',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );

    final relationId = await services.propertyAuthoring.createProperty(
      objectTypeId: sourceTypeId,
      name: 'Author',
      type: ObjectPropertyType.objectRelation,
      relationTargetObjectTypeId: targetTypeId,
      relationMultiple: false,
    );
    final textId = await services.propertyAuthoring.createProperty(
      objectTypeId: sourceTypeId,
      name: 'URL',
      type: ObjectPropertyType.url,
    );

    final source = (await objectStore.getObjectType(sourceTypeId))!;
    final relation = source.properties.singleWhere((p) => p.id == relationId);
    final value = source.properties.singleWhere((p) => p.id == textId);

    expect(relation.targetObjectTypeId, targetTypeId);
    expect(relation.allowsMultipleRelations, isFalse);

    final relationImpact = await services.relationSchemaEvolution.inspectChange(
      property: relation,
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    expect(relationImpact.changesCardinality, isTrue);

    final valueImpact = await services.valueTypeConversion.inspectChange(
      objectTypeId: sourceTypeId,
      propertyId: value.id,
      nextType: ObjectPropertyType.text,
    );
    expect(valueImpact.property.id, value.id);
    expect(valueImpact.nextType, ObjectPropertyType.text);

    final deleteImpact = await services.propertySchema.inspectDelete(
      objectTypeId: sourceTypeId,
      propertyId: value.id,
    );
    expect(deleteImpact.property.id, value.id);
  });
}
