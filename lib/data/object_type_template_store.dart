import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';

import '../database/database_definition.dart';
import '../domain/object_model.dart';
import 'database_view_gallery_adapter.dart';
import 'database_view_store.dart';
import 'file_object_service.dart';
import 'generic_database_store.dart';
import 'image_object_service.dart';
import 'object_store.dart';
import 'object_type_template_primitive_target_resolver.dart';
import 'tag_object_bridge.dart';
import 'weblink_object_service.dart';

class ObjectTypeTemplateProperty {
  const ObjectTypeTemplateProperty({
    required this.name,
    required this.type,
    this.config = const <String, dynamic>{},
    this.relationTargetSystemKey,
    this.relationMultiple = true,
  });

  final String name;
  final String type;
  final Map<String, dynamic> config;

  /// Stable primitive identity used only while instantiating Relation schema.
  ///
  /// The resolved ObjectType id is persisted by the canonical Relation API; the
  /// template never stores a workspace-specific id.
  final String? relationTargetSystemKey;
  final bool relationMultiple;
}

enum ObjectTypeTemplateGalleryCoverKind {
  imageRelation,
  weblinkRelationRepresentativeImage,
}

class ObjectTypeTemplateView {
  const ObjectTypeTemplateView({
    required this.name,
    this.layoutType = 'table',
    this.filters = const <String, dynamic>{},
    this.sorts = const <dynamic>[],
    this.settings = const <String, dynamic>{},
    this.galleryCoverRelationPropertyName,
    this.galleryCoverKind,
  }) : assert(
          (galleryCoverRelationPropertyName == null) ==
              (galleryCoverKind == null),
        );

  final String name;
  final String layoutType;
  final Map<String, dynamic> filters;
  final List<dynamic> sorts;
  final Map<String, dynamic> settings;

  /// Template-local Relation name resolved to the newly-created stable
  /// Property id while instantiating this View. Workspace-specific ids never
  /// enter the static template definition.
  final String? galleryCoverRelationPropertyName;
  final ObjectTypeTemplateGalleryCoverKind? galleryCoverKind;
}

class ObjectTypeTemplate {
  const ObjectTypeTemplate({
    required this.key,
    required this.name,
    required this.icon,
    required this.description,
    required this.properties,
    this.version = 1,
    this.views = const <ObjectTypeTemplateView>[],
  }) : assert(version > 0);

  final String key;
  final int version;
  final String name;
  final String icon;
  final String description;
  final List<ObjectTypeTemplateProperty> properties;
  final List<ObjectTypeTemplateView> views;
}

class ObjectTypeTemplateInstance {
  const ObjectTypeTemplateInstance({
    required this.objectTypeId,
    required this.templateKey,
    required this.templateVersion,
  });

  final int objectTypeId;
  final String templateKey;
  final int templateVersion;
}

class ObjectTypeTemplateStore {
  ObjectTypeTemplateStore(this.store);

  final GenericDatabaseStore store;

  static const templates = <ObjectTypeTemplate>[
    ObjectTypeTemplate(
      key: 'book',
      name: '書籍',
      icon: '📚',
      description: '著者、状態、評価、URLを持つ読書データベース',
      properties: [
        ObjectTypeTemplateProperty(name: '著者', type: 'text'),
        ObjectTypeTemplateProperty(
          name: '状態',
          type: 'select',
          config: {
            'options': ['未読', '読書中', '読了'],
          },
        ),
        ObjectTypeTemplateProperty(name: '評価', type: 'rating'),
        ObjectTypeTemplateProperty(name: 'URL', type: 'url'),
        ObjectTypeTemplateProperty(name: 'メモ', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(name: 'すべて', layoutType: 'gallery'),
      ],
    ),
    ObjectTypeTemplate(
      key: 'paper',
      name: '論文',
      icon: '📄',
      description: 'Weblink、表紙、ファイル、タグを組み合わせる論文データベース',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Weblink',
          type: 'relation',
          relationTargetSystemKey: WeblinkObjectService.systemKey,
          relationMultiple: false,
        ),
        ObjectTypeTemplateProperty(
          name: '表紙',
          type: 'relation',
          relationTargetSystemKey: ImageObjectService.systemKey,
          relationMultiple: false,
        ),
        ObjectTypeTemplateProperty(
          name: 'ファイル',
          type: 'relation',
          relationTargetSystemKey: FileObjectService.systemKey,
          relationMultiple: true,
        ),
        ObjectTypeTemplateProperty(
          name: 'タグ',
          type: 'relation',
          relationTargetSystemKey: TagObjectBridge.systemKey,
          relationMultiple: true,
        ),
        ObjectTypeTemplateProperty(name: 'DOI', type: 'text'),
        ObjectTypeTemplateProperty(name: '公開日', type: 'date'),
        ObjectTypeTemplateProperty(name: 'メモ', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'ライブラリ',
          layoutType: 'gallery',
          galleryCoverRelationPropertyName: '表紙',
          galleryCoverKind: ObjectTypeTemplateGalleryCoverKind.imageRelation,
        ),
        ObjectTypeTemplateView(name: '一覧', layoutType: 'table'),
      ],
    ),
    ObjectTypeTemplate(
      key: 'person',
      name: '人物',
      icon: '👤',
      description: '所属、役割、連絡先、メモを持つ人物データベース',
      properties: [
        ObjectTypeTemplateProperty(name: '所属', type: 'text'),
        ObjectTypeTemplateProperty(name: '役割', type: 'text'),
        ObjectTypeTemplateProperty(name: 'URL', type: 'url'),
        ObjectTypeTemplateProperty(name: 'メモ', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(name: 'すべて', layoutType: 'table'),
      ],
    ),
    ObjectTypeTemplate(
      key: 'project',
      name: 'プロジェクト',
      icon: '🚀',
      description: '状態、期限、優先度、メモを持つプロジェクトデータベース',
      properties: [
        ObjectTypeTemplateProperty(
          name: '状態',
          type: 'select',
          config: {
            'options': ['未着手', '進行中', '完了', '保留'],
          },
        ),
        ObjectTypeTemplateProperty(name: '期限', type: 'date'),
        ObjectTypeTemplateProperty(
          name: '優先度',
          type: 'select',
          config: {
            'options': ['低', '中', '高'],
          },
        ),
        ObjectTypeTemplateProperty(name: 'メモ', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(name: 'すべて', layoutType: 'table'),
      ],
    ),
    ObjectTypeTemplate(
      key: 'note',
      name: 'ノート',
      icon: '📝',
      description: '分類、URL、メモを持つシンプルな知識データベース',
      properties: [
        ObjectTypeTemplateProperty(name: '分類', type: 'multiSelect'),
        ObjectTypeTemplateProperty(name: 'URL', type: 'url'),
        ObjectTypeTemplateProperty(name: 'メモ', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(name: 'すべて', layoutType: 'list'),
      ],
    ),
    ObjectTypeTemplate(
      key: 'plant',
      name: '植物',
      icon: '🪴',
      description: '写真、タグ、購入日、育成メモを組み合わせる汎用植物データベース',
      properties: [
        ObjectTypeTemplateProperty(
          name: '写真',
          type: 'relation',
          relationTargetSystemKey: ImageObjectService.systemKey,
          relationMultiple: true,
        ),
        ObjectTypeTemplateProperty(
          name: 'タグ',
          type: 'relation',
          relationTargetSystemKey: TagObjectBridge.systemKey,
          relationMultiple: true,
        ),
        ObjectTypeTemplateProperty(name: '購入日', type: 'date'),
        ObjectTypeTemplateProperty(name: '育成メモ', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: '一覧',
          layoutType: 'gallery',
          galleryCoverRelationPropertyName: '写真',
          galleryCoverKind: ObjectTypeTemplateGalleryCoverKind.imageRelation,
        ),
      ],
    ),
  ];

  ObjectTypeTemplate? templateByKey(String key) {
    for (final template in templates) {
      if (template.key == key) return template;
    }
    return null;
  }

  Future<void> _ensureInstanceSchema() async {
    await store.ensureSchema();
    await store.database.customStatement('''
      CREATE TABLE IF NOT EXISTS object_type_template_instances (
        object_type_id INTEGER PRIMARY KEY
          REFERENCES generic_databases(id) ON DELETE CASCADE,
        template_key TEXT NOT NULL,
        template_version INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await store.database.customStatement(
      'CREATE INDEX IF NOT EXISTS object_type_template_instances_key_idx '
      'ON object_type_template_instances(template_key, template_version)',
    );
  }

  Future<ObjectTypeTemplateInstance?> instanceForObjectType(
    int objectTypeId,
  ) async {
    await _ensureInstanceSchema();
    final row = await store.database.customSelect(
      '''SELECT object_type_id, template_key, template_version
         FROM object_type_template_instances
         WHERE object_type_id = ? LIMIT 1''',
      variables: [Variable<int>(objectTypeId)],
    ).getSingleOrNull();
    if (row == null) return null;
    return ObjectTypeTemplateInstance(
      objectTypeId: row.read<int>('object_type_id'),
      templateKey: row.read<String>('template_key'),
      templateVersion: row.read<int>('template_version'),
    );
  }

  Future<int> createFromTemplate({
    required int workspaceId,
    required ObjectTypeTemplate template,
    String? name,
    String? icon,
  }) async {
    await _ensureInstanceSchema();
    final objectStore = ObjectStore(store);
    final primitiveTargets = ObjectTypeTemplatePrimitiveTargetResolver(
      genericStore: store,
      objectStore: objectStore,
    );
    final viewStore = DatabaseViewStore(store.database);

    final relationTargets = <ObjectTypeTemplateProperty, int>{};
    for (final property in template.properties) {
      if (property.type != 'relation') continue;
      final systemKey = property.relationTargetSystemKey?.trim() ?? '';
      if (systemKey.isEmpty) {
        throw ArgumentError(
          'Relation template Property ${property.name} requires a target system key.',
        );
      }
      final target = await primitiveTargets.resolveOrProvision(
        workspaceId: workspaceId,
        systemKey: systemKey,
      );
      if (target == null) {
        throw StateError(
          'Required primitive ObjectType "$systemKey" is not available in this workspace.',
        );
      }
      relationTargets[property] = target.id;
    }

    return store.database.transaction(() async {
      final objectTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: name?.trim().isNotEmpty == true ? name!.trim() : template.name,
        icon: icon?.trim().isNotEmpty == true ? icon!.trim() : template.icon,
      );

      final createdPropertyIds = <String, int>{};
      for (final property in template.properties) {
        if (createdPropertyIds.containsKey(property.name)) {
          throw StateError(
            'Template ${template.key} contains duplicate Property name "${property.name}".',
          );
        }
        final propertyId = property.type == 'relation'
            ? await objectStore.createRelationProperty(
                objectTypeId: objectTypeId,
                name: property.name,
                targetObjectTypeId: relationTargets[property]!,
                multiple: property.relationMultiple,
              )
            : await objectStore.createProperty(
                objectTypeId: objectTypeId,
                name: property.name,
                type: ObjectPropertyDefinition.fromStorageType(property.type),
                config: property.config,
              );
        createdPropertyIds[property.name] = propertyId;
      }

      final definition = DatabaseDefinition(
        key: 'custom:$objectTypeId',
        label: name?.trim().isNotEmpty == true ? name!.trim() : template.name,
        icon: Icons.table_chart_outlined,
        properties: const <DatabasePropertyDefinition>[],
      );
      for (final view in template.views) {
        final settings = <String, dynamic>{...view.settings};
        final coverPropertyName = view.galleryCoverRelationPropertyName;
        final coverKind = view.galleryCoverKind;
        if (coverPropertyName != null && coverKind != null) {
          final templateProperties = template.properties
              .where((property) => property.name == coverPropertyName)
              .toList(growable: false);
          if (templateProperties.length != 1 ||
              templateProperties.single.type != 'relation') {
            throw StateError(
              'Template View ${view.name} Gallery cover must reference exactly one Relation Property.',
            );
          }
          final propertyId = createdPropertyIds[coverPropertyName];
          if (propertyId == null) {
            throw StateError(
              'Template View ${view.name} Gallery cover Property was not created.',
            );
          }
          final source = switch (coverKind) {
            ObjectTypeTemplateGalleryCoverKind.imageRelation =>
              GalleryCoverSource.imageRelation(propertyId),
            ObjectTypeTemplateGalleryCoverKind
                  .weblinkRelationRepresentativeImage =>
              GalleryCoverSource.weblinkRelationRepresentativeImage(propertyId),
          };
          settings[DatabaseViewGalleryAdapter.coverSourceSettingsKey] =
              source.toStorage();
        }

        await viewStore.createView(
          workspaceId: workspaceId,
          definition: definition,
          name: view.name,
          layoutType: view.layoutType,
          filters: view.filters,
          sorts: view.sorts,
          visibleProperties: const <String>[],
          propertyOrder: const <String>[],
          settings: settings,
        );
      }

      await store.database.customStatement(
        '''INSERT INTO object_type_template_instances(
             object_type_id, template_key, template_version
           ) VALUES (?, ?, ?)''',
        [objectTypeId, template.key, template.version],
      );
      return objectTypeId;
    });
  }
}
