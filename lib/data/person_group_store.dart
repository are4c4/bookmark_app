import 'package:drift/drift.dart';

import 'app_database.dart';

class PersonGroupInfo {
  const PersonGroupInfo({required this.id, required this.name});

  final int id;
  final String name;
}

/// Lightweight persistence for grouping people without forcing a hard parent/child
/// relationship between people. A person may belong to any number of groups.
class PersonGroupStore {
  PersonGroupStore(this.database);

  final AppDatabase database;
  Future<void>? _schemaReady;

  Future<void> _ensureSchema() => _schemaReady ??= database.transaction(() async {
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS person_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS person_group_members (
            group_id INTEGER NOT NULL REFERENCES person_groups(id) ON DELETE CASCADE,
            person_id INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
            PRIMARY KEY (group_id, person_id)
          )
        ''');
        await database.customStatement(
          'CREATE INDEX IF NOT EXISTS person_group_members_person_idx '
          'ON person_group_members(person_id)',
        );
      });

  Future<List<PersonGroupInfo>> listGroups() async {
    await _ensureSchema();
    final rows = await database.customSelect(
      'SELECT id, name FROM person_groups ORDER BY lower(name), id',
    ).get();
    return rows
        .map(
          (row) => PersonGroupInfo(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
          ),
        )
        .toList();
  }

  Future<int> createGroup(String name) async {
    await _ensureSchema();
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('Group name is empty');
    final existing = await database.customSelect(
      'SELECT id FROM person_groups WHERE lower(name) = lower(?) LIMIT 1',
      variables: [Variable<String>(value)],
    ).getSingleOrNull();
    if (existing != null) return existing.read<int>('id');
    await database.customStatement(
      'INSERT INTO person_groups(name) VALUES (?)',
      [value],
    );
    final row = await database.customSelect(
      'SELECT id FROM person_groups WHERE name = ? LIMIT 1',
      variables: [Variable<String>(value)],
    ).getSingle();
    return row.read<int>('id');
  }

  Future<void> renameGroup(int id, String name) async {
    await _ensureSchema();
    final value = name.trim();
    if (value.isEmpty) return;
    await database.customStatement(
      'UPDATE person_groups SET name = ? WHERE id = ?',
      [value, id],
    );
  }

  Future<void> deleteGroup(int id) async {
    await _ensureSchema();
    await database.customStatement('DELETE FROM person_groups WHERE id = ?', [id]);
  }

  Future<Set<int>> memberIds(int groupId) async {
    await _ensureSchema();
    final rows = await database.customSelect(
      'SELECT person_id FROM person_group_members WHERE group_id = ?',
      variables: [Variable<int>(groupId)],
    ).get();
    return rows.map((row) => row.read<int>('person_id')).toSet();
  }

  Future<List<PersonGroupInfo>> groupsForPerson(int personId) async {
    await _ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT g.id, g.name
      FROM person_groups g
      INNER JOIN person_group_members m ON m.group_id = g.id
      WHERE m.person_id = ?
      ORDER BY lower(g.name), g.id
      ''',
      variables: [Variable<int>(personId)],
    ).get();
    return rows
        .map(
          (row) => PersonGroupInfo(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
          ),
        )
        .toList();
  }

  Future<void> setGroupsForPerson(int personId, Iterable<int> groupIds) async {
    await _ensureSchema();
    await database.transaction(() async {
      await database.customStatement(
        'DELETE FROM person_group_members WHERE person_id = ?',
        [personId],
      );
      for (final groupId in groupIds.toSet()) {
        await database.customStatement(
          'INSERT OR IGNORE INTO person_group_members(group_id, person_id) VALUES (?, ?)',
          [groupId, personId],
        );
      }
    });
  }

  Future<void> addPerson(int groupId, int personId) async {
    await _ensureSchema();
    await database.customStatement(
      'INSERT OR IGNORE INTO person_group_members(group_id, person_id) VALUES (?, ?)',
      [groupId, personId],
    );
  }

  Future<void> removePerson(int groupId, int personId) async {
    await _ensureSchema();
    await database.customStatement(
      'DELETE FROM person_group_members WHERE group_id = ? AND person_id = ?',
      [groupId, personId],
    );
  }
}
