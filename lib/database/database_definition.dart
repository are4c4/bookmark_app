import 'package:flutter/material.dart';

enum DatabasePropertyType {
  text,
  number,
  select,
  multiSelect,
  relation,
  date,
  checkbox,
  rating,
  file,
  url,
  image,
}

class DatabasePropertyDefinition {
  const DatabasePropertyDefinition({
    required this.key,
    required this.label,
    required this.type,
    required this.icon,
    this.defaultVisible = true,
  });

  final String key;
  final String label;
  final DatabasePropertyType type;
  final IconData icon;
  final bool defaultVisible;
}

class DatabaseDefinition {
  const DatabaseDefinition({
    required this.key,
    required this.label,
    required this.icon,
    required this.properties,
    this.defaultLayout = 'gallery',
    this.supportedLayouts = const ['gallery', 'list', 'table'],
  });

  final String key;
  final String label;
  final IconData icon;
  final List<DatabasePropertyDefinition> properties;
  final String defaultLayout;
  final List<String> supportedLayouts;

  List<String> get defaultVisibleProperties => properties
      .where((property) => property.defaultVisible)
      .map((property) => property.key)
      .toList();

  List<String> get defaultPropertyOrder =>
      properties.map((property) => property.key).toList();
}

class BuiltInDatabases {
  static const bookmarks = DatabaseDefinition(
    key: 'bookmarks',
    label: 'ブックマーク',
    icon: Icons.bookmarks_outlined,
    properties: [
      DatabasePropertyDefinition(key: 'image', label: '画像', type: DatabasePropertyType.image, icon: Icons.image_outlined),
      DatabasePropertyDefinition(key: 'url', label: 'URL', type: DatabasePropertyType.url, icon: Icons.link),
      DatabasePropertyDefinition(key: 'status', label: 'ステータス', type: DatabasePropertyType.select, icon: Icons.flag_outlined),
      DatabasePropertyDefinition(key: 'rating', label: '評価', type: DatabasePropertyType.rating, icon: Icons.star_outline),
      DatabasePropertyDefinition(key: 'tags', label: 'タグ', type: DatabasePropertyType.multiSelect, icon: Icons.sell_outlined),
      DatabasePropertyDefinition(key: 'genre', label: 'ジャンル', type: DatabasePropertyType.select, icon: Icons.category_outlined),
      DatabasePropertyDefinition(key: 'people', label: '人物', type: DatabasePropertyType.relation, icon: Icons.person_outline),
      DatabasePropertyDefinition(key: 'collections', label: 'コレクション', type: DatabasePropertyType.relation, icon: Icons.collections_bookmark_outlined),
      DatabasePropertyDefinition(key: 'description', label: '説明', type: DatabasePropertyType.text, icon: Icons.notes_outlined, defaultVisible: false),
      DatabasePropertyDefinition(key: 'createdAt', label: '登録日時', type: DatabasePropertyType.date, icon: Icons.schedule_outlined, defaultVisible: false),
      DatabasePropertyDefinition(key: 'favorite', label: 'お気に入り', type: DatabasePropertyType.checkbox, icon: Icons.star_outline),
      DatabasePropertyDefinition(key: 'history', label: '履歴', type: DatabasePropertyType.number, icon: Icons.history, defaultVisible: false),
    ],
  );

  static const people = DatabaseDefinition(
    key: 'people',
    label: '人物',
    icon: Icons.people_outline,
    properties: [
      DatabasePropertyDefinition(key: 'profileImage', label: 'プロフィール画像', type: DatabasePropertyType.image, icon: Icons.account_circle_outlined),
      DatabasePropertyDefinition(key: 'name', label: '名前', type: DatabasePropertyType.text, icon: Icons.person_outline),
      DatabasePropertyDefinition(key: 'note', label: 'メモ', type: DatabasePropertyType.text, icon: Icons.notes_outlined),
      DatabasePropertyDefinition(key: 'groups', label: '所属', type: DatabasePropertyType.relation, icon: Icons.group_outlined),
      DatabasePropertyDefinition(key: 'bookmarks', label: '関連ブックマーク', type: DatabasePropertyType.relation, icon: Icons.bookmarks_outlined),
      DatabasePropertyDefinition(key: 'createdAt', label: '登録日時', type: DatabasePropertyType.date, icon: Icons.schedule_outlined, defaultVisible: false),
    ],
  );

  static const photos = DatabaseDefinition(
    key: 'photos',
    label: '写真',
    icon: Icons.photo_library_outlined,
    properties: [
      DatabasePropertyDefinition(key: 'image', label: '画像', type: DatabasePropertyType.image, icon: Icons.image_outlined),
      DatabasePropertyDefinition(key: 'title', label: 'タイトル', type: DatabasePropertyType.text, icon: Icons.title),
      DatabasePropertyDefinition(key: 'tags', label: 'タグ', type: DatabasePropertyType.multiSelect, icon: Icons.sell_outlined),
      DatabasePropertyDefinition(key: 'note', label: 'メモ', type: DatabasePropertyType.text, icon: Icons.notes_outlined),
      DatabasePropertyDefinition(key: 'bookmarks', label: '関連ブックマーク', type: DatabasePropertyType.relation, icon: Icons.bookmarks_outlined),
      DatabasePropertyDefinition(key: 'createdAt', label: '登録日時', type: DatabasePropertyType.date, icon: Icons.schedule_outlined, defaultVisible: false),
    ],
  );

  static const collections = DatabaseDefinition(
    key: 'collections',
    label: 'コレクション',
    icon: Icons.collections_bookmark_outlined,
    properties: [
      DatabasePropertyDefinition(key: 'name', label: '名前', type: DatabasePropertyType.text, icon: Icons.title),
      DatabasePropertyDefinition(key: 'note', label: '説明', type: DatabasePropertyType.text, icon: Icons.notes_outlined),
      DatabasePropertyDefinition(key: 'bookmarks', label: 'ブックマーク', type: DatabasePropertyType.relation, icon: Icons.bookmarks_outlined),
      DatabasePropertyDefinition(key: 'createdAt', label: '登録日時', type: DatabasePropertyType.date, icon: Icons.schedule_outlined, defaultVisible: false),
    ],
    defaultLayout: 'list',
  );

  static const all = [bookmarks, people, photos, collections];

  static DatabaseDefinition? byKey(String key) {
    for (final database in all) {
      if (database.key == key) return database;
    }
    return null;
  }
}
