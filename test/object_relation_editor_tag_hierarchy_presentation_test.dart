import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_identity_search_service.dart';
import 'package:bookmark_app/data/object_relation_editor_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late ObjectAliasStore aliasStore;
  late ObjectRelationEditorService service;
  late TagObjectBridge tagBridge;
  late TagObjectSchema tagSchema;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    aliasStore = ObjectAliasStore(genericStore);
    final relationTargets = RelationTargetService(objectStore);
    final relationMutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    service = ObjectRelationEditorService(
      targets: relationTargets,
      mutations: relationMutations,
      identitySearch: ObjectIdentitySearchService(
        objectStore: objectStore,
        aliasStore: aliasStore,
      ),
    );
    tagBridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    tagSchema = await tagBridge.ensureTagObjectType(workspaceId);
  });

  tearDown(() => database.close());

  Future<int> createTag(String title, {int? parentObjectId}) async {
    final objectId = await objectStore.createObject(
      objectTypeId: tagSchema.objectType.id,
      title: title,
    );
    if (parentObjectId != null) {
      await tagBridge.hierarchyIntegrity.setParent(
        workspaceId: workspaceId,
        tagObjectId: objectId,
        parentProperty: tagSchema.parentProperty,
        parentTagObjectId: parentObjectId,
      );
    }
    return objectId;
  }

  Future<({int sourceId, ObjectPropertyDefinition property})>
      createSourceRelation(int targetObjectTypeId) async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final property = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Tags',
      targetObjectTypeId: targetObjectTypeId,
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );
    return (sourceId: sourceId, property: property);
  }

  test(
    'Tag candidates expose canonical hierarchy paths for ambiguous titles',
    () async {
      final math = await createTag('数学');
      final algebra = await createTag('代数学', parentObjectId: math);
      final numberTheory = await createTag('数論', parentObjectId: algebra);
      final geometry = await createTag('幾何学', parentObjectId: math);
      final geometricTheory = await createTag('数論', parentObjectId: geometry);
      final source = await createSourceRelation(tagSchema.objectType.id);

      final context = await service.load(
        workspaceId: workspaceId,
        sourceObjectId: source.sourceId,
        property: source.property,
      );
      final results = await service.searchCandidates(
        context: context,
        query: '数論',
      );

      expect(
        {for (final result in results) result.objectId: result.aliasContext},
        <int, String?>{
          numberTheory: '数学 › 代数学 › 数論',
          geometricTheory: '数学 › 幾何学 › 数論',
        },
      );
    },
  );

  test(
    'root Tag omits redundant path and alias keeps hierarchy context',
    () async {
      final math = await createTag('数学');
      final algebra = await createTag('代数学', parentObjectId: math);
      final numberTheory = await createTag('数論', parentObjectId: algebra);
      await aliasStore.addAlias(objectId: numberTheory, alias: 'NT');
      final source = await createSourceRelation(tagSchema.objectType.id);
      final context = await service.load(
        workspaceId: workspaceId,
        sourceObjectId: source.sourceId,
        property: source.property,
      );

      final root = await service.searchCandidates(
        context: context,
        query: '数学',
      );
      expect(root.single.objectId, math);
      expect(root.single.aliasContext, isNull);

      final alias = await service.searchCandidates(
        context: context,
        query: 'NT',
      );
      expect(alias.single.objectId, numberTheory);
      expect(alias.single.matchedAlias, 'NT');
      expect(alias.single.aliasContext, '数学 › 代数学 › 数論 · 別名: NT');
    },
  );

  test('non-Tag Relation search keeps existing alias presentation', () async {
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Jean-Pierre Serre',
    );
    await aliasStore.addAlias(objectId: personId, alias: 'JP');
    final source = await createSourceRelation(personTypeId);
    final context = await service.load(
      workspaceId: workspaceId,
      sourceObjectId: source.sourceId,
      property: source.property,
    );

    final results = await service.searchCandidates(
      context: context,
      query: 'JP',
    );

    expect(results.single.objectId, personId);
    expect(results.single.presentationContext, isNull);
    expect(results.single.aliasContext, '別名: JP');
  });
}
