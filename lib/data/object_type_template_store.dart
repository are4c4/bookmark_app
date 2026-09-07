import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';

import '../database/database_definition.dart';
import '../domain/object_group.dart';
import '../domain/object_model.dart';
import '../domain/object_query.dart';
import 'database_view_gallery_adapter.dart';
import 'database_view_group_adapter.dart';
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

class ObjectTypeTemplateFilter {
  const ObjectTypeTemplateFilter({
    required this.propertyName,
    required this.operator,
    this.value,
  });

  /// Template-local Property name resolved after schema creation.
  final String propertyName;
  final ObjectFilterOperator operator;
  final dynamic value;
}

class ObjectTypeTemplateSort {
  const ObjectTypeTemplateSort({
    required this.propertyName,
    required this.direction,
  });

  /// Template-local Property name resolved after schema creation.
  final String propertyName;
  final ObjectSortDirection direction;
}

class ObjectTypeTemplateGroup {
  const ObjectTypeTemplateGroup({
    required this.propertyName,
    this.includeEmpty = true,
  });

  /// Template-local Property name resolved after schema creation.
  final String propertyName;
  final bool includeEmpty;
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
    this.propertyFilters = const <ObjectTypeTemplateFilter>[],
    this.propertySorts = const <ObjectTypeTemplateSort>[],
    this.group,
    this.visiblePropertyNames = const <String>[],
    this.propertyOrderNames = const <String>[],
    this.settings = const <String, dynamic>{},
    this.galleryCoverRelationPropertyName,
    this.galleryCoverKind,
  }) : assert(
          (galleryCoverRelationPropertyName == null) ==
              (galleryCoverKind == null),
        );

  final String name;
  final String layoutType;

  /// Raw persisted View query configuration kept for backwards compatibility.
  final Map<String, dynamic> filters;
  final List<dynamic> sorts;

  /// Template-local query/group rules resolved to newly-created Property ids.
  final List<ObjectTypeTemplateFilter> propertyFilters;
  final List<ObjectTypeTemplateSort> propertySorts;
  final ObjectTypeTemplateGroup? group;

  /// Template-local Property names resolved to stable `p:<id>` View tokens
  /// after this template has created its user-owned schema.
  final List<String> visiblePropertyNames;
  final List<String> propertyOrderNames;
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
      key: 'bookmark',
      name: 'ブックマーク',
      icon: '🔖',
      description: 'Weblink、タグ、カバー、ファイル、評価を組み合わせる汎用ブックマークデータベース',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Weblink',
          type: 'relation',
          relationTargetSystemKey: WeblinkObjectService.systemKey,
          relationMultiple: false,
        ),
        ObjectTypeTemplateProperty(
          name: 'タグ',
          type: 'relation',
          relationTargetSystemKey: TagObjectBridge.systemKey,
          relationMultiple: true,
        ),
        ObjectTypeTemplateProperty(
          name: 'カバー',
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
        ObjectTypeTemplateProperty(name: '評価', type: 'rating'),
        ObjectTypeTemplateProperty(
          name: '状態',
          type: 'select',
          config: {
            'options': ['あとで読む', '読了'],
          },
        ),
        ObjectTypeTemplateProperty(name: 'お気に入り', type: 'checkbox'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'すべて',
          layoutType: 'gallery',
          visiblePropertyNames: ['状態', 'お気に入り', '評価', 'タグ'],
          propertyOrderNames: [
            'Weblink',
            '状態',
            'お気に入り',
            '評価',
            'タグ',
            'カバー',
            'ファイル',
          ],
          galleryCoverRelationPropertyName: 'カバー',
          galleryCoverKind: ObjectTypeTemplateGalleryCoverKind.imageRelation,
        ),
        ObjectTypeTemplateView(
          name: 'あとで読む',
          layoutType: 'gallery',
          propertyFilters: [
            ObjectTypeTemplateFilter(
              propertyName: '状態',
              operator: ObjectFilterOperator.equals,
              value: 'あとで読む',
            ),
          ],
          visiblePropertyNames: ['評価', 'タグ'],
          galleryCoverRelationPropertyName: 'カバー',
          galleryCoverKind: ObjectTypeTemplateGalleryCoverKind.imageRelation,
        ),
        ObjectTypeTemplateView(
          name: 'お気に入り',
          layoutType: 'gallery',
          propertyFilters: [
            ObjectTypeTemplateFilter(
              propertyName: 'お気に入り',
              operator: ObjectFilterOperator.equals,
              value: true,
            ),
          ],
          visiblePropertyNames: ['状態', '評価', 'タグ'],
          galleryCoverRelationPropertyName: 'カバー',
          galleryCoverKind: ObjectTypeTemplateGalleryCoverKind.imageRelation,
        ),
      ],
    ),
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

  void _preflightTemplate(ObjectTypeTemplate template) {
    if (template.version <= 0) {
      throw StateError('Template ${template.key} must use a positive version.');
    }

    final propertiesByName = <String, ObjectTypeTemplateProperty>{};
    for (final property in template.properties) {
      final canonicalName = property.name.trim();
      if (canonicalName.isEmpty) {
        throw StateError(
          'Template ${template.key} contains a blank Property name.',
        );
      }
      if (propertiesByName.containsKey(canonicalName)) {
        throw StateError(
          'Template ${template.key} contains duplicate Property name "$canonicalName".',
        );
      }
      if (canonicalName != property.name) {
        throw StateError(
          'Template ${template.key} Property name "${property.name}" is not canonical; leading or trailing whitespace would be removed on persistence.',
        );
      }
      propertiesByName[canonicalName] = property;

      if (property.type == 'relation') {
        final systemKey = property.relationTargetSystemKey?.trim() ?? '';
        if (systemKey.isEmpty) {
          throw ArgumentError(
            'Relation template Property ${property.name} requires a target system key.',
          );
        }
        if (systemKey != WeblinkObjectService.systemKey &&
            systemKey != ImageObjectService.systemKey &&
            systemKey != FileObjectService.systemKey &&
            systemKey != TagObjectBridge.systemKey) {
          throw StateError(
            'Required primitive ObjectType "$systemKey" is not available for template provisioning.',
          );
        }
        continue;
      }

      final parsedType = ObjectPropertyDefinition.fromStorageType(property.type);
      final canonicalType = ObjectPropertyDefinition(
        id: -1,
        objectTypeId: -1,
        name: property.name,
        type: parsedType,
        sortOrder: 0,
      ).storageType;
      if (canonicalType != property.type) {
        throw StateError(
          'Template Property ${property.name} uses unsupported type "${property.type}".',
        );
      }
    }

    void validateViewPropertyNames(
      ObjectTypeTemplateView view,
      Iterable<String> propertyNames,
      String fieldName, {
      bool rejectDuplicates = false,
    }) {
      final seen = <String>{};
      for (final propertyName in propertyNames) {
        final canonicalName = propertyName.trim();
        if (canonicalName.isEmpty || canonicalName != propertyName) {
          throw StateError(
            'Template View ${view.name} $fieldName must reference a canonical Property name, not "$propertyName".',
          );
        }
        if (rejectDuplicates && !seen.add(canonicalName)) {
          throw StateError(
            'Template View ${view.name} $fieldName contains duplicate Property "$canonicalName".',
          );
        }
        if (!propertiesByName.containsKey(canonicalName)) {
          throw StateError(
            'Template View ${view.name} $fieldName references unknown Property "$canonicalName".',
          );
        }
      }
    }

    bool isGroupable(ObjectTypeTemplateProperty property) {
      final type = ObjectPropertyDefinition.fromStorageType(property.type);
      return switch (type) {
        ObjectPropertyType.title ||
        ObjectPropertyType.image ||
        ObjectPropertyType.file ||
        ObjectPropertyType.createdTime ||
        ObjectPropertyType.updatedTime => false,
        _ => true,
      };
    }

    for (final view in template.views) {
      final coverPropertyName = view.galleryCoverRelationPropertyName;
      final coverKind = view.galleryCoverKind;
      if ((coverPropertyName == null) != (coverKind == null)) {
        throw StateError(
          'Template View ${view.name} Gallery cover requires both a Relation Property and cover kind.',
        );
      }
      if (coverPropertyName != null && coverKind != null) {
        final canonicalCoverPropertyName = coverPropertyName.trim();
        if (canonicalCoverPropertyName.isEmpty ||
            canonicalCoverPropertyName != coverPropertyName) {
          throw StateError(
            'Template View ${view.name} Gallery cover must reference a canonical Property name, not "$coverPropertyName".',
          );
        }
        final relationProperty = propertiesByName[canonicalCoverPropertyName];
        if (relationProperty == null || relationProperty.type != 'relation') {
          throw StateError(
            'Template View ${view.name} Gallery cover must reference exactly one Relation Property.',
          );
        }
        final expectedSystemKey = switch (coverKind) {
          ObjectTypeTemplateGalleryCoverKind.imageRelation =>
            ImageObjectService.systemKey,
          ObjectTypeTemplateGalleryCoverKind.weblinkRelationRepresentativeImage =>
            WeblinkObjectService.systemKey,
        };
        final actualSystemKey =
            relationProperty.relationTargetSystemKey?.trim() ?? '';
        if (actualSystemKey != expectedSystemKey) {
          throw StateError(
            'Template View ${view.name} Gallery cover kind requires a Relation targeting "$expectedSystemKey", not "$actualSystemKey".',
          );
        }
      }

      validateViewPropertyNames(
        view,
        view.visiblePropertyNames,
        'visible Properties',
        rejectDuplicates: true,
      );
      validateViewPropertyNames(
        view,
        view.propertyOrderNames,
        'Property order',
        rejectDuplicates: true,
      );
      validateViewPropertyNames(
        view,
        view.propertyFilters.map((rule) => rule.propertyName),
        'filter',
      );
      validateViewPropertyNames(
        view,
        view.propertySorts.map((rule) => rule.propertyName),
        'sort',
      );

      final group = view.group;
      if (group != null) {
        validateViewPropertyNames(view, [group.propertyName], 'group');
        if (view.settings.containsKey(DatabaseViewGroupAdapter.groupSettingsKey)) {
          throw StateError(
            'Template View ${view.name} must not define both a template-local group and raw groupRule settings.',
          );
        }
        final groupProperty = propertiesByName[group.propertyName]!;
        if (!isGroupable(groupProperty)) {
          throw StateError(
            'Template View ${view.name} group references non-groupable Property "${group.propertyName}".',
          );
        }
      }

      if (view.propertyFilters.isNotEmpty) {
        final rawRules = view.filters['propertyRules'];
        if (rawRules != null && rawRules is! List) {
          throw StateError(
            'Template View ${view.name} raw propertyRules must be a list before template-local filters can be appended.',
          );
        }
      }
    }
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
    _preflightTemplate(template);
    await _ensureInstanceSchema();
    final objectStore = ObjectStore(store);
    final primitiveTargets = ObjectTypeTemplatePrimitiveTargetResolver(
      genericStore: store,
      objectStore: objectStore,
    );
    final viewStore = DatabaseViewStore(store.database);

    final galleryCoverRelations =
        <ObjectTypeTemplateView, ObjectTypeTemplateProperty>{};
    for (final view in template.views) {
      final coverPropertyName = view.galleryCoverRelationPropertyName;
      final coverKind = view.galleryCoverKind;
      if ((coverPropertyName == null) != (coverKind == null)) {
        throw StateError(
          'Template View ${view.name} Gallery cover requires both a Relation Property and cover kind.',
        );
      }
      if (coverPropertyName == null || coverKind == null) continue;

      final matchingProperties = template.properties
          .where((property) => property.name == coverPropertyName)
          .toList(growable: false);
      if (matchingProperties.length != 1 ||
          matchingProperties.single.type != 'relation') {
        throw StateError(
          'Template View ${view.name} Gallery cover must reference exactly one Relation Property.',
        );
      }
      final relationProperty = matchingProperties.single;
      final expectedSystemKey = switch (coverKind) {
        ObjectTypeTemplateGalleryCoverKind.imageRelation =>
          ImageObjectService.systemKey,
        ObjectTypeTemplateGalleryCoverKind.weblinkRelationRepresentativeImage =>
          WeblinkObjectService.systemKey,
      };
      final actualSystemKey =
          relationProperty.relationTargetSystemKey?.trim() ?? '';
      if (actualSystemKey != expectedSystemKey) {
        throw StateError(
          'Template View ${view.name} Gallery cover kind requires a Relation targeting "$expectedSystemKey", not "$actualSystemKey".',
        );
      }
      galleryCoverRelations[view] = relationProperty;
    }

    return store.database.transaction(() async {
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

      int resolveViewPropertyId(
        ObjectTypeTemplateView view,
        String propertyName,
        String fieldName,
      ) {
        final propertyId = createdPropertyIds[propertyName];
        if (propertyId == null) {
          throw StateError(
            'Template View ${view.name} $fieldName references unknown Property "$propertyName".',
          );
        }
        return propertyId;
      }

      List<String> resolveViewProperties(
        ObjectTypeTemplateView view,
        List<String> propertyNames,
        String fieldName,
      ) {
        final resolved = <String>[];
        final seen = <String>{};
        for (final propertyName in propertyNames) {
          if (!seen.add(propertyName)) {
            throw StateError(
              'Template View ${view.name} $fieldName contains duplicate Property "$propertyName".',
            );
          }
          final propertyId = resolveViewPropertyId(
            view,
            propertyName,
            fieldName,
          );
          resolved.add('p:$propertyId');
        }
        return resolved;
      }

      Map<String, dynamic> resolveViewFilters(ObjectTypeTemplateView view) {
        if (view.propertyFilters.isEmpty) return view.filters;
        final rawRules = view.filters['propertyRules'];
        if (rawRules != null && rawRules is! List) {
          throw StateError(
            'Template View ${view.name} raw propertyRules must be a list before template-local filters can be appended.',
          );
        }
        return <String, dynamic>{
          ...view.filters,
          'propertyRules': <dynamic>[
            if (rawRules is List) ...rawRules,
            for (final rule in view.propertyFilters)
              <String, dynamic>{
                'propertyId': resolveViewPropertyId(
                  view,
                  rule.propertyName,
                  'filter',
                ),
                'operator': rule.operator.name,
                if (rule.value != null) 'value': rule.value,
              },
          ],
        };
      }

      List<dynamic> resolveViewSorts(ObjectTypeTemplateView view) {
        if (view.propertySorts.isEmpty) return view.sorts;
        return <dynamic>[
          ...view.sorts,
          for (final rule in view.propertySorts)
            <String, dynamic>{
              'propertyId': resolveViewPropertyId(
                view,
                rule.propertyName,
                'sort',
              ),
              'direction': rule.direction.name,
            },
        ];
      }

      final definition = DatabaseDefinition(
        key: 'custom:$objectTypeId',
        label: name?.trim().isNotEmpty == true ? name!.trim() : template.name,
        icon: Icons.table_chart_outlined,
        properties: const <DatabasePropertyDefinition>[],
      );
      for (final view in template.views) {
        var settings = <String, dynamic>{...view.settings};
        final group = view.group;
        if (group != null) {
          settings = const DatabaseViewGroupAdapter().encodeSettings(
            settings,
            group: ObjectGroupRule(
              propertyId: resolveViewPropertyId(
                view,
                group.propertyName,
                'group',
              ),
              includeEmpty: group.includeEmpty,
            ),
          );
        }
        final coverPropertyName = view.galleryCoverRelationPropertyName;
        final coverKind = view.galleryCoverKind;
        if (coverPropertyName != null && coverKind != null) {
          final relationProperty = galleryCoverRelations[view];
          if (relationProperty == null) {
            throw StateError(
              'Template View ${view.name} Gallery cover Relation was not validated.',
            );
          }
          final propertyId = createdPropertyIds[relationProperty.name];
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
          filters: resolveViewFilters(view),
          sorts: resolveViewSorts(view),
          visibleProperties: resolveViewProperties(
            view,
            view.visiblePropertyNames,
            'visible Properties',
          ),
          propertyOrder: resolveViewProperties(
            view,
            view.propertyOrderNames,
            'Property order',
          ),
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
