import '../data/app_database.dart';

enum AutoOrganizeMatchField {
  url('url', 'URL'),
  title('title', 'タイトル'),
  description('description', '説明'),
  all('all', 'すべて');

  const AutoOrganizeMatchField(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static AutoOrganizeMatchField fromStorage(String value) {
    for (final field in values) {
      if (field.storageValue == value) return field;
    }
    return all;
  }
}

class AutoOrganizeRule {
  const AutoOrganizeRule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.matchField,
    required this.keyword,
    required this.tagName,
    required this.genre,
  });

  final int id;
  final String name;
  final bool enabled;
  final AutoOrganizeMatchField matchField;
  final String keyword;
  final String tagName;
  final String genre;
}

class AutoOrganizeResult {
  const AutoOrganizeResult({
    required this.bookmarksChanged,
    required this.rulesMatched,
  });

  final int bookmarksChanged;
  final int rulesMatched;
}

class AutoOrganizeService {
  AutoOrganizeService(this._database);

  final AppDatabase _database;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _database.customStatement(
      'CREATE TABLE IF NOT EXISTS auto_organize_rules ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, '
      'enabled INTEGER NOT NULL DEFAULT 1, '
      'match_field TEXT NOT NULL DEFAULT \'all\', '
      'keyword TEXT NOT NULL, '
      'tag_name TEXT NOT NULL DEFAULT \'\', '
      'genre TEXT NOT NULL DEFAULT \'\', '
      'created_at TEXT NOT NULL'
      ')',
    );
    _initialized = true;
  }

  Future<List<AutoOrganizeRule>> listRules() async {
    await initialize();
    final rows = await _database.customSelect(
      'SELECT id, name, enabled, match_field, keyword, tag_name, genre '
      'FROM auto_organize_rules ORDER BY id',
    ).get();
    return rows
        .map(
          (row) => AutoOrganizeRule(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            enabled: row.read<int>('enabled') != 0,
            matchField: AutoOrganizeMatchField.fromStorage(
              row.read<String>('match_field'),
            ),
            keyword: row.read<String>('keyword'),
            tagName: row.read<String>('tag_name'),
            genre: row.read<String>('genre'),
          ),
        )
        .toList();
  }

  Future<int> createRule({
    required String name,
    required AutoOrganizeMatchField matchField,
    required String keyword,
    String tagName = '',
    String genre = '',
  }) async {
    await initialize();
    final normalizedName = name.trim();
    final normalizedKeyword = keyword.trim();
    final normalizedTag = tagName.trim();
    final normalizedGenre = genre.trim();
    if (normalizedName.isEmpty || normalizedKeyword.isEmpty) {
      throw ArgumentError('ルール名とキーワードは必須です');
    }
    if (normalizedTag.isEmpty && normalizedGenre.isEmpty) {
      throw ArgumentError('付与するタグまたはジャンルを指定してください');
    }
    await _database.customStatement(
      'INSERT INTO auto_organize_rules '
      '(name, enabled, match_field, keyword, tag_name, genre, created_at) '
      'VALUES (?, 1, ?, ?, ?, ?, ?)',
      [
        normalizedName,
        matchField.storageValue,
        normalizedKeyword,
        normalizedTag,
        normalizedGenre,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    final row = await _database.customSelect(
      'SELECT last_insert_rowid() AS id',
    ).getSingle();
    return row.read<int>('id');
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await initialize();
    await _database.customStatement(
      'UPDATE auto_organize_rules SET enabled = ? WHERE id = ?',
      [enabled ? 1 : 0, id],
    );
  }

  Future<void> deleteRule(int id) async {
    await initialize();
    await _database.customStatement(
      'DELETE FROM auto_organize_rules WHERE id = ?',
      [id],
    );
  }

  bool _matches(
    AutoOrganizeRule rule, {
    required String url,
    required String title,
    String? description,
  }) {
    final value = switch (rule.matchField) {
      AutoOrganizeMatchField.url => url,
      AutoOrganizeMatchField.title => title,
      AutoOrganizeMatchField.description => description ?? '',
      AutoOrganizeMatchField.all => '$url $title ${description ?? ''}',
    };
    return value.toLowerCase().contains(rule.keyword.toLowerCase());
  }

  Future<int> applyToBookmark({
    required int bookmarkId,
    required String url,
    required String title,
    String? description,
  }) async {
    final rules = await listRules();
    var matched = 0;
    for (final rule in rules.where((candidate) => candidate.enabled)) {
      if (!_matches(
        rule,
        url: url,
        title: title,
        description: description,
      )) {
        continue;
      }
      matched++;
      if (rule.tagName.isNotEmpty) {
        await _database.addTagsToBookmarks([bookmarkId], [rule.tagName]);
      }
      if (rule.genre.isNotEmpty) {
        await _database.setGenre(bookmarkId, rule.genre);
      }
    }
    return matched;
  }

  Future<AutoOrganizeResult> applyToAll(
    Iterable<BookmarkItem> bookmarks,
  ) async {
    var changed = 0;
    var matched = 0;
    for (final bookmark in bookmarks) {
      final count = await applyToBookmark(
        bookmarkId: bookmark.id,
        url: bookmark.url,
        title: bookmark.title,
        description: bookmark.description,
      );
      if (count > 0) changed++;
      matched += count;
    }
    return AutoOrganizeResult(
      bookmarksChanged: changed,
      rulesMatched: matched,
    );
  }
}
