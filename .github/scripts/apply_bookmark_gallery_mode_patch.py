from __future__ import annotations

import hashlib
import re
from pathlib import Path

STAGE1 = Path('lib/views/bookmark_unified_stage1_page.dart')
TEST = Path('test/bookmark_unified_stage1_gallery_mode_test.dart')
EXPECTED_STAGE1_BLOB = '591f84013e3be9deebb20cf968689c44d5153a50'


def git_blob_sha(data: bytes) -> str:
    payload = f'blob {len(data)}\0'.encode() + data
    return hashlib.sha1(payload).hexdigest()


def replace_once(text: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected exactly one anchor, found {count}: {old[:100]!r}')
    return text.replace(old, new, 1)


data = STAGE1.read_bytes()
actual_blob = git_blob_sha(data)
if actual_blob != EXPECTED_STAGE1_BLOB:
    raise SystemExit(
        f'Stage1 blob changed before patch: expected {EXPECTED_STAGE1_BLOB}, got {actual_blob}'
    )
text = data.decode('utf-8')

text = replace_once(
    text,
    "import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';\n",
    '',
)
text = replace_once(
    text,
    "import '../data/bookmark_repository.dart';\n",
    "import '../data/bookmark_repository.dart';\n"
    "import '../data/database_view_gallery_adapter.dart';\n",
)
text = replace_once(
    text,
    "import '../features/database/presentation/widgets/database_view_tabs.dart';\n",
    "import '../features/database/presentation/widgets/database_view_tabs.dart';\n"
    "import '../features/database/presentation/widgets/object_gallery_view.dart';\n",
)
text = replace_once(
    text,
    "import '../widgets/notion_bookmark_card.dart';\n",
    "import '../widgets/notion_bookmark_card.dart';\n"
    "import '../widgets/object_gallery_mode_menu.dart';\n",
)
text = replace_once(
    text,
    '  static const _openPresentationHost = ObjectOpenPresentationHost();\n',
    '  static const _galleryAdapter = DatabaseViewGalleryAdapter();\n'
    '  static const _openPresentationHost = ObjectOpenPresentationHost();\n',
)

view_tabs_anchor = '  Widget _databaseViewTabs() => Padding(\n'
persist_helper = '''  Future<void> _persistDatabaseView(DatabaseViewConfig next) async {
    await _databaseViewStore.updateView(next);
    if (!mounted || _activeDatabaseViewId != next.id) return;
    setState(() => _activeDatabaseView = next);
  }

'''
text = replace_once(text, view_tabs_anchor, persist_helper + view_tabs_anchor)

gallery_pattern = re.compile(
    r'  Widget _gallery\(List<BookmarkItem> bookmarks\) => LayoutBuilder\(.*?'
    r'\n      \);\n\n  Widget _image\(',
    re.DOTALL,
)
gallery_matches = gallery_pattern.findall(text)
if len(gallery_matches) != 1:
    raise SystemExit(f'Expected one legacy Bookmark Gallery block, found {len(gallery_matches)}')

gallery_new = '''  Widget _gallery(List<BookmarkItem> bookmarks) {
    final scheme = Theme.of(context).colorScheme;
    final activeView = _activeDatabaseView;
    final mode = activeView == null
        ? GalleryViewMode.fixed
        : _galleryAdapter.decode(activeView);
    return ObjectGalleryView(
      mode: mode,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
      fixedMainAxisExtent: 360,
      itemCount: bookmarks.length + 1,
      itemBuilder: (context, index) {
        if (index == bookmarks.length) {
          return DatabaseActionCard(
            label: '新しいブックマーク',
            icon: Icons.add,
            onPressed: () => showBookmarkCreateDialog(
              context: context,
              repository: widget.repository,
            ),
          );
        }
        final bookmark = bookmarks[index];
        final selected = _selectionMode
            ? _batchSelectedIds.contains(bookmark.id)
            : bookmark.id == _selectedBookmarkId;
        return Stack(children: [
          _roleAwareCard(bookmark, selected: selected),
          if (_selectionMode)
            Positioned(
              left: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: _batchSelectedIds.contains(bookmark.id),
                  onChanged: (_) => _selectBookmark(bookmark),
                ),
              ),
            ),
        ]);
      },
    );
  }

  Widget _image('''
text = gallery_pattern.sub(gallery_new, text, count=1)

toolbar_anchor = '''        TextButton.icon(
          onPressed: _showPropertiesDialog,
          icon: const Icon(Icons.tune, size: 17),
          label: const Text('プロパティ'),
        ),
'''
toolbar_addition = toolbar_anchor + '''        if (_viewType == BookmarkStage1ViewType.gallery &&
            _activeDatabaseView != null)
          ObjectGalleryModeMenu(
            view: _activeDatabaseView!,
            onViewChanged: (next) => unawaited(_persistDatabaseView(next)),
          ),
'''
text = replace_once(text, toolbar_anchor, toolbar_addition)

STAGE1.write_text(text, encoding='utf-8')

TEST.write_text(
    r'''import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/bookmark_unified_stage1_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bookmark Gallery switches and persists fixed/masonry mode',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    await repository.create(
      url: 'https://example.com/gallery-mode',
      title: 'Gallery mode bookmark',
    );

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: BookmarkUnifiedStage1Page(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gallery-mode-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-gallery-fixed')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-gallery-masonry')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('gallery-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('メイソンリー'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('object-gallery-fixed')), findsNothing);
    expect(find.byKey(const ValueKey('object-gallery-masonry')), findsOneWidget);

    final views = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: BuiltInDatabases.bookmarks.key,
    );
    expect(views, isNotEmpty);
    expect(views.first.settings['galleryMode'], 'masonry');

    await tester.tap(find.byKey(const ValueKey('gallery-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('固定比率'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('object-gallery-fixed')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-gallery-masonry')), findsNothing);

    final fixedViews = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: BuiltInDatabases.bookmarks.key,
    );
    expect(fixedViews.first.settings['galleryMode'], 'fixed');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
''',
    encoding='utf-8',
)
