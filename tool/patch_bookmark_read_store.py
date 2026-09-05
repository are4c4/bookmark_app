from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


app_path = Path('lib/data/app_database.dart')
app = app_path.read_text()
start = '  Stream<List<BookmarkItem>> watchBookmarkItems() {'
end = '  Stream<List<Tag>> watchAllTags()'
if app.count(start) != 1 or app.count(end) != 1:
    raise SystemExit('app_database watchBookmarkItems markers are not unique')
start_index = app.index(start)
end_index = app.index(end)
if end_index <= start_index:
    raise SystemExit('app_database watchBookmarkItems markers are out of order')
app = app[:start_index] + app[end_index:]
app_path.write_text(app)

repo_path = Path('lib/data/bookmark_repository.dart')
repo = repo_path.read_text()
repo = replace_once(
    repo,
    "import 'bookmark_attachment_store.dart';\n",
    "import 'bookmark_attachment_store.dart';\nimport 'bookmark_read_store.dart';\n",
    'bookmark_repository import',
)
repo = replace_once(
    repo,
    "  }) : autoOrganize =\n            autoOrganizeService ?? AutoOrganizeService(_database);",
    "  })  : _bookmarkReads = BookmarkReadStore(_database),\n        autoOrganize = autoOrganizeService ?? AutoOrganizeService(_database);",
    'bookmark_repository initializer',
)
repo = replace_once(
    repo,
    '  final AppDatabase _database;\n',
    '  final AppDatabase _database;\n  final BookmarkReadStore _bookmarkReads;\n',
    'bookmark_repository field',
)
repo = replace_once(
    repo,
    '        _database.watchBookmarkItems(),\n',
    '        _bookmarkReads.watchItems(),\n',
    'bookmark_repository watch source',
)
repo_path.write_text(repo)

sync_path = Path('lib/services/object_sync_service.dart')
sync = sync_path.read_text()
sync = replace_once(
    sync,
    "import '../data/bookmark_weblink_object_bridge.dart';\n",
    "import '../data/bookmark_read_store.dart';\nimport '../data/bookmark_weblink_object_bridge.dart';\n",
    'object_sync import',
)
sync = replace_once(
    sync,
    '      database.watchBookmarkItems().map<Object?>((_) => null),\n',
    '      BookmarkReadStore(database).watchItems().map<Object?>((_) => null),\n',
    'object_sync watch source',
)
sync_path.write_text(sync)
