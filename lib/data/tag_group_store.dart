import 'dart:async';

import 'package:drift/drift.dart';

import 'app_database.dart';

class TagGroupInfo {
  const TagGroupInfo({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int sortOrder;
}

class TagGroupStore {
  TagGroupStore(this.database);

  final AppDatabase database;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<void> initialize() async {
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS tag_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    final columns = await database.customSelect('PRAGMA table_info(tags)').get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    if (!names.contains('group_id')) {
      await database.customStatement('ALTER TABLE tags ADD COLUMN group_id INTEGER');
    }
  }

  Future<List<TagGroupInfo>> listGroups() async {
    final rows = await database.customSelect(
      'SELECT id, name, sort_order FROM tag_groups ORDER BY sort_order, name COLLATE NOCASE',
    ).get();
    return rows
        .map((row) => TagGroupInfo(
              id: row.read<int>('id'),
              name: row.read<String>('name'),
              sortOrder: row.read<int>('sort_order'),
            ))
        .toList();
  }

  Stream<List<TagGroupInfo>> watchGroups() async* {
    yield await listGroups();
    await for (final _ in changes) {
      yield await listGroups();
    }
  }

  Future<Map<int, int?>> tagGroupIds() async {
    final rows = await database.customSelect(
      'SELECT id, group_id FROM tags',
      readsFrom: {database.tags},
    ).get();
    return {
      for (final row in rows) row.read<int>('id'): row.readNullable<int>('group_id'),
    };
  }

  Stream<Map<int, int?>> watchTagGroupIds() async* {
    yield await tagGroupIds();
    await for (final _ in changes) {
      yield await tagGroupIds();
    }
  }

  Future<int> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('グループ名が空です');
    final maxRow = await database.customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM tag_groups',
    ).getSingle();
    final nextOrder = maxRow.read<int>('max_order') + 1;
    await database.customStatement(
      'INSERT INTO tag_groups (name, sort_order) VALUES (?, ?)',
      [trimmed, nextOrder],
    );
    final row = await database.customSelect(
      'SELECT id FROM tag_groups WHERE name = ?',
      variables: [Variable<String>(trimmed)],
    ).getSingle();
    _changes.add(null);
    return row.read<int>('id');
  }

  Future<void> renameGroup(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await database.customUpdate(
      'UPDATE tag_groups SET name = ? WHERE id = ?',
      variables: [Variable<String>(trimmed), Variable<int>(id)],
    );
    _changes.add(null);
  }

  Future<void> deleteGroup(int id) async {
    await database.transaction(() async {
      await database.customUpdate(
        'UPDATE tags SET group_id = NULL WHERE group_id = ?',
        variables: [Variable<int>(id)],
        updates: {database.tags},
      );
      await database.customUpdate(
        'DELETE FROM tag_groups WHERE id = ?',
        variables: [Variable<int>(id)],
      );
    });
    _changes.add(null);
  }

  Future<void> setTagGroup(int tagId, int? groupId) async {
    await database.customUpdate(
      'UPDATE tags SET group_id = ? WHERE id = ?',
      variables: [
        groupId == null ? const Variable<int>(null) : Variable<int>(groupId),
        Variable<int>(tagId),
      ],
      updates: {database.tags},
    );
    _changes.add(null);
  }

  Future<void> reorderGroups(List<int> ids) async {
    await database.transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await database.customUpdate(
          'UPDATE tag_groups SET sort_order = ? WHERE id = ?',
          variables: [Variable<int>(i), Variable<int>(ids[i])],
        );
      }
    });
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
