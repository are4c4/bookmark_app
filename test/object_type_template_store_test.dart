import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in templates expose stable unique keys, versions, schemas, and Views', () {
    final templates = ObjectTypeTemplateStore.templates;
    final keys = templates.map((item) => item.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(keys.toSet(), {
      'book',
      'person',
      'project',
      'note',
      'plant',
    });
    expect(templates.every((template) => template.version == 1), isTrue);
    expect(templates.every((template) => template.views.isNotEmpty), isTrue);
    expect(
      templates.firstWhere((item) => item.key == 'book').properties
          .map((property) => property.name),
      containsAll(['著者', '状態', '評価', 'URL', 'メモ']),
    );
    final plant = templates.firstWhere((item) => item.key == 'plant');
    expect(
      plant.properties.map((property) => property.name),
      ['写真', 'タグ', '購入日', '育成メモ'],
    );
    expect(plant.views.single.layoutType, 'gallery');
  });

  test('createFromTemplate creates user-owned schema and default View atomically', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);
    final template = templateStore.templateByKey('project')!;

    final databaseId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: template,
      name: '修論プロジェクト',
    );

    final created = await genericStore.getDatabase(databaseId);
    expect(created?.name, '修論プロジェクト');
    expect(created?.icon, '🚀');

    final objectType = await ObjectStore(genericStore).getObjectType(databaseId);
    expect(objectType?.kind, ObjectTypeKind.custom);

    final properties = await genericStore.listProperties(databaseId);
    expect(
      properties.map((property) => property.name).toList(),
      ['状態', '期限', '優先度', 'メモ'],
    );
    expect(properties.first.type, 'select');
    expect(
      properties.first.config['options'],
      ['未着手', '進行中', '完了', '保留'],
    );

    final views = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$databaseId',
    );
    expect(views, hasLength(1));
    expect(views.single.name, 'すべて');
    expect(views.single.layoutType, 'table');

    final provenance = await templateStore.instanceForObjectType(databaseId);
    expect(provenance?.templateKey, 'project');
    expect(provenance?.templateVersion, 1);
  });

  test('template defaults can be overridden without mutating template', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);
    final template = templateStore.templateByKey('note')!;

    final databaseId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: template,
      name: '研究メモ',
      icon: '🧠',
    );

    final created = await genericStore.getDatabase(databaseId);
    expect(created?.name, '研究メモ');
    expect(created?.icon, '🧠');
    expect(template.name, 'ノート');
    expect(template.icon, '📝');
  });

  test('template Relation resolves primitive by stable key and remains user-owned', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final weblinkType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    final templateStore = ObjectTypeTemplateStore(genericStore);
    const paper = ObjectTypeTemplate(
      key: 'paper',
      version: 3,
      name: 'Paper',
      icon: '📄',
      description: 'generic Paper regression template',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Weblink',
          type: 'relation',
          relationTargetSystemKey: WeblinkObjectService.systemKey,
          relationMultiple: false,
        ),
        ObjectTypeTemplateProperty(name: 'DOI', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: '読む',
          layoutType: 'gallery',
          settings: {'openMode': 'sidePeek'},
        ),
      ],
    );

    final objectTypeId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: paper,
    );

    final created = await objectStore.getObjectType(objectTypeId);
    expect(created?.kind, ObjectTypeKind.custom);
    final relation = created!.properties.firstWhere(
      (property) => property.name == 'Weblink',
    );
    expect(relation.type, ObjectPropertyType.objectRelation);
    expect(relation.targetObjectTypeId, weblinkType.id);
    expect(relation.allowsMultipleRelations, isFalse);

    final views = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$objectTypeId',
    );
    expect(views.single.name, '読む');
    expect(views.single.layoutType, 'gallery');
    expect(views.single.settings['openMode'], 'sidePeek');

    final provenance = await templateStore.instanceForObjectType(objectTypeId);
    expect(provenance?.templateKey, 'paper');
    expect(provenance?.templateVersion, 3);

    await objectStore.renameObjectType(objectTypeId, 'My Papers');
    await genericStore.setDatabaseIcon(objectTypeId, '🧪');
    final customized = await genericStore.getDatabase(objectTypeId);
    expect(customized?.name, 'My Papers');
    expect(customized?.icon, '🧪');
    expect((await templateStore.instanceForObjectType(objectTypeId))?.templateVersion, 3);
  });

  test('Plant template composes Image and Tag primitives without domain-specific code', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'image',
      name: 'Images',
      icon: '🖼️',
    );
    final tagType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag',
      name: 'Tags',
      icon: '🏷️',
    );
    final templateStore = ObjectTypeTemplateStore(genericStore);

    final objectTypeId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: templateStore.templateByKey('plant')!,
    );

    final created = await objectStore.getObjectType(objectTypeId);
    expect(created?.kind, ObjectTypeKind.custom);
    final photo = created!.properties.firstWhere((property) => property.name == '写真');
    final tags = created.properties.firstWhere((property) => property.name == 'タグ');
    expect(photo.targetObjectTypeId, imageType.id);
    expect(photo.allowsMultipleRelations, isTrue);
    expect(tags.targetObjectTypeId, tagType.id);
    expect(tags.allowsMultipleRelations, isTrue);

    final views = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$objectTypeId',
    );
    expect(views.single.name, '一覧');
    expect(views.single.layoutType, 'gallery');
  });

  test('missing primitive Relation target fails before creating user schema', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);
    const broken = ObjectTypeTemplate(
      key: 'broken',
      name: 'Broken',
      icon: '⚠️',
      description: 'missing primitive target',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Missing',
          type: 'relation',
          relationTargetSystemKey: 'missing-primitive',
        ),
      ],
    );

    final before = await genericStore.listAllDatabases(workspaceId);
    await expectLater(
      templateStore.createFromTemplate(
        workspaceId: workspaceId,
        template: broken,
      ),
      throwsStateError,
    );
    final after = await genericStore.listAllDatabases(workspaceId);
    expect(after.length, before.length);
  });
}
