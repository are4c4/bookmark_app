import 'package:drift/drift.dart';

import 'app_database.dart';

enum BookmarkPropertyType { text, number, date, select, checkbox }

class BookmarkPropertyDefinition {
  const BookmarkPropertyDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.options,
  });

  final int id;
  final String name;
  final BookmarkPropertyType type;
  final List<String> options;
}

class BookmarkPropertyValue {
  const BookmarkPropertyValue({
    required this.definition,
    required this.value,
  });

  final BookmarkPropertyDefinition definition;
  final String? value;
}

class CustomPropertyStore {
  CustomPropertyStore(this.database);

  final AppDatabase database;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS custom_properties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL,
        options TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS bookmark_custom_values (
        bookmark_id INTEGER NOT NULL,
        property_id INTEGER NOT NULL,
        value TEXT,
        PRIMARY KEY (bookmark_id, property_id),
        FOREIGN KEY (bookmark_id) REFERENCES bookmarks(id) ON DELETE CASCADE,
        FOREIGN KEY (property_id) REFERENCES custom_properties(id) ON DELETE CASCADE
      )
    ''');
    _initialized = true;
  }

  BookmarkPropertyType _parseType(String value) =>
      BookmarkPropertyType.values.where((type) => type.name == value).firstOrNull ??
      BookmarkPropertyType.text;

  List<String> _parseOptions(String value) => value
      .split('\n')
      .map((option) => option.trim())
      .where((option) => option.isNotEmpty)
      .toList();

  String _encodeOptions(Iterable<String> options) => options
      .map((option) => option.trim())
      .where((option) => option.isNotEmpty)
      .toSet()
      .join('\n');

  Future<List<BookmarkPropertyDefinition>> getDefinitions() async {
    await _ensureInitialized();
    final rows = await database.customSelect(
      'SELECT id, name, type, options FROM custom_properties ORDER BY id',
    ).get();
    return rows
        .map(
          (row) => BookmarkPropertyDefinition(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            type: _parseType(row.read<String>('type')),
            options: _parseOptions(row.read<String>('options')),
          ),
        )
        .toList();
  }

  Future<int> createDefinition({
    required String name,
    required BookmarkPropertyType type,
    Iterable<String> options = const [],
  }) async {
    await _ensureInitialized();
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Property name is empty');
    await database.customStatement(
      'INSERT INTO custom_properties (name, type, options) VALUES (?, ?, ?)',
      [
        Variable<String>(trimmed),
        Variable<String>(type.name),
        Variable<String>(_encodeOptions(options)),
      ],
    );
    final row = await database.customSelect(
      'SELECT id FROM custom_properties WHERE name = ?',
      variables: [Variable<String>(trimmed)],
    ).getSingle();
    return row.read<int>('id');
  }

  Future<void> updateDefinition(
    BookmarkPropertyDefinition definition, {
    required String name,
    required BookmarkPropertyType type,
    Iterable<String> options = const [],
  }) async {
    await _ensureInitialized();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await database.customStatement(
      'UPDATE custom_properties SET name = ?, type = ?, options = ? WHERE id = ?',
      [
        Variable<String>(trimmed),
        Variable<String>(type.name),
        Variable<String>(_encodeOptions(options)),
        Variable<int>(definition.id),
      ],
    );
  }

  Future<void> deleteDefinition(BookmarkPropertyDefinition definition) async {
    await _ensureInitialized();
    await database.customStatement(
      'DELETE FROM custom_properties WHERE id = ?',
      [Variable<int>(definition.id)],
    );
  }

  Future<List<BookmarkPropertyValue>> getValues(int bookmarkId) async {
    await _ensureInitialized();
    final definitions = await getDefinitions();
    final rows = await database.customSelect(
      'SELECT property_id, value FROM bookmark_custom_values WHERE bookmark_id = ?',
      variables: [Variable<int>(bookmarkId)],
    ).get();
    final values = <int, String?>{
      for (final row in rows)
        row.read<int>('property_id'): row.readNullable<String>('value'),
    };
    return definitions
        .map(
          (definition) => BookmarkPropertyValue(
            definition: definition,
            value: values[definition.id],
          ),
        )
        .toList();
  }

  Future<void> setValue(
    int bookmarkId,
    BookmarkPropertyDefinition definition,
    String? value,
  ) async {
    await _ensureInitialized();
    if (value == null) {
      await database.customStatement(
        'DELETE FROM bookmark_custom_values WHERE bookmark_id = ? AND property_id = ?',
        [Variable<int>(bookmarkId), Variable<int>(definition.id)],
      );
      return;
    }
    await database.customStatement(
      '''
      INSERT INTO bookmark_custom_values (bookmark_id, property_id, value)
      VALUES (?, ?, ?)
      ON CONFLICT(bookmark_id, property_id)
      DO UPDATE SET value = excluded.value
      ''',
      [
        Variable<int>(bookmarkId),
        Variable<int>(definition.id),
        Variable<String>(value),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
