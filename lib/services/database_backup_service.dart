import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../data/app_database.dart';

class DatabaseBackupService {
  const DatabaseBackupService(this.database);

  final AppDatabase database;

  static const _tables = <String>[
    'bookmarks',
    'tag_groups',
    'tags',
    'bookmark_tags',
    'people',
    'bookmark_people',
    'photos',
    'bookmark_photos',
    'collections',
    'bookmark_collections',
    'bookmark_relations',
    'saved_views',
    'saved_view_tags',
    'workspaces',
    'bookmark_workspace',
    'saved_view_workspace',
    'workspace_settings',
    'bookmark_attachments',
    'pdf_annotations',
    'person_groups',
    'person_group_members',
  ];

  static const _jsonTypeGroup = XTypeGroup(
    label: 'Bookmark App backup',
    extensions: ['json'],
  );

  Future<Map<String, Object?>> createSnapshot() async {
    final availableRows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final available = availableRows
        .map((row) => row.read<String>('name'))
        .toSet();
    final tables = <String, Object?>{};
    for (final table in _tables) {
      if (!available.contains(table)) continue;
      final rows = await database.customSelect('SELECT * FROM "$table"').get();
      tables[table] = rows.map((row) => _jsonSafeMap(row.data)).toList();
    }
    return <String, Object?>{
      'format': 'bookmark_app_backup',
      'formatVersion': 1,
      'schemaVersion': database.schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  Future<String?> exportToFile() async {
    final location = await getSaveLocation(
      suggestedName: 'bookmark_app_backup_${_dateStamp()}.json',
      acceptedTypeGroups: const [_jsonTypeGroup],
    );
    if (location == null) return null;
    final snapshot = await createSnapshot();
    final encoder = const JsonEncoder.withIndent('  ');
    await File(location.path).writeAsString(encoder.convert(snapshot));
    return location.path;
  }

  Future<String?> chooseBackupFile() async {
    final file = await openFile(acceptedTypeGroups: const [_jsonTypeGroup]);
    return file?.path;
  }

  Future<void> restoreFromFile(String path) async {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'bookmark_app_backup' ||
        decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException('Bookmark App のバックアップファイルではありません。');
    }
    final backupSchema = decoded['schemaVersion'];
    if (backupSchema is int && backupSchema > database.schemaVersion) {
      throw StateError(
        'このバックアップは新しいDBバージョン ($backupSchema) で作成されています。アプリを更新してください。',
      );
    }

    final rawTables = decoded['tables'] as Map<String, dynamic>;
    final availableRows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final available = availableRows
        .map((row) => row.read<String>('name'))
        .toSet();

    await database.transaction(() async {
      await database.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in _tables.reversed) {
        if (available.contains(table)) {
          await database.customStatement('DELETE FROM "$table"');
        }
      }
      for (final table in _tables) {
        if (!available.contains(table)) continue;
        final rawRows = rawTables[table];
        if (rawRows is! List) continue;
        for (final rawRow in rawRows) {
          if (rawRow is! Map) continue;
          final row = rawRow.map(
            (key, value) => MapEntry(key.toString(), _restoreValue(value)),
          );
          if (row.isEmpty) continue;
          final columns = row.keys.toList();
          final columnSql = columns.map((column) => '"$column"').join(', ');
          final placeholders = List.filled(columns.length, '?').join(', ');
          await database.customStatement(
            'INSERT INTO "$table" ($columnSql) VALUES ($placeholders)',
            columns.map((column) => row[column]).toList(),
          );
        }
      }
    });
  }

  Map<String, Object?> _jsonSafeMap(Map<String, Object?> input) => input.map(
        (key, value) => MapEntry(key, _jsonSafeValue(value)),
      );

  Object? _jsonSafeValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) {
      return <String, Object?>{'__type': 'datetime', 'value': value.toIso8601String()};
    }
    return value.toString();
  }

  Object? _restoreValue(Object? value) {
    if (value is Map && value['__type'] == 'datetime') {
      return DateTime.tryParse(value['value']?.toString() ?? '')?.millisecondsSinceEpoch;
    }
    return value;
  }

  String _dateStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }
}
