import 'generic_database_store.dart';

class ObjectTypeTemplateProperty {
  const ObjectTypeTemplateProperty({
    required this.name,
    required this.type,
    this.config = const <String, dynamic>{},
  });

  final String name;
  final String type;
  final Map<String, dynamic> config;
}

class ObjectTypeTemplate {
  const ObjectTypeTemplate({
    required this.key,
    required this.name,
    required this.icon,
    required this.description,
    required this.properties,
  });

  final String key;
  final String name;
  final String icon;
  final String description;
  final List<ObjectTypeTemplateProperty> properties;
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
    ),
  ];

  ObjectTypeTemplate? templateByKey(String key) {
    for (final template in templates) {
      if (template.key == key) return template;
    }
    return null;
  }

  Future<int> createFromTemplate({
    required int workspaceId,
    required ObjectTypeTemplate template,
    String? name,
    String? icon,
  }) async {
    await store.ensureSchema();
    return store.database.transaction(() async {
      final databaseId = await store.createDatabase(
        workspaceId: workspaceId,
        name: name?.trim().isNotEmpty == true ? name!.trim() : template.name,
        icon: icon?.trim().isNotEmpty == true ? icon!.trim() : template.icon,
      );
      for (final property in template.properties) {
        await store.createProperty(
          databaseId: databaseId,
          name: property.name,
          type: property.type,
          config: property.config,
        );
      }
      return databaseId;
    });
  }
}
