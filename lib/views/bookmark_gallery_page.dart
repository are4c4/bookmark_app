import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_metadata_service.dart';

enum BookmarkViewType { gallery, list, table }

class BookmarkGalleryPage extends StatefulWidget {
  const BookmarkGalleryPage({
    super.key,
    required this.repository,
  });

  final BookmarkRepository repository;

  @override
  State<BookmarkGalleryPage> createState() => _BookmarkGalleryPageState();
}

class _BookmarkGalleryPageState extends State<BookmarkGalleryPage> {
  final _searchController = TextEditingController();
  BookmarkViewType _viewType = BookmarkViewType.gallery;
  String _query = '';
  int? _selectedTagId;
  bool _favoritesOnly = false;
  int? _activeSavedViewId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _parseTags(String value) => value
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();

  String _layoutName(BookmarkViewType type) => switch (type) {
        BookmarkViewType.gallery => 'gallery',
        BookmarkViewType.list => 'list',
        BookmarkViewType.table => 'table',
      };

  BookmarkViewType _layoutFromName(String value) => switch (value) {
        'list' => BookmarkViewType.list,
        'table' => BookmarkViewType.table,
        _ => BookmarkViewType.gallery,
      };

  List<BookmarkItem> _filterBookmarks(List<BookmarkItem> bookmarks) {
    final query = _query.trim().toLowerCase();
    return bookmarks.where((bookmark) {
      if (_favoritesOnly && !bookmark.favorite) return false;
      if (_selectedTagId != null &&
          !bookmark.tags.any((tag) => tag.id == _selectedTagId)) {
        return false;
      }
      if (query.isEmpty) return true;
      return bookmark.title.toLowerCase().contains(query) ||
          bookmark.url.toLowerCase().contains(query) ||
          (bookmark.description ?? '').toLowerCase().contains(query) ||
          bookmark.tags.any((tag) => tag.name.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _openBookmark(BookmarkItem bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URLを開けませんでした')),
      );
    }
  }

  Future<void> _showAddBookmarkDialog() async {
    final urlController = TextEditingController();
    final tagsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (saving || !(formKey.currentState?.validate() ?? false)) return;
            setDialogState(() => saving = true);
            try {
              final metadata = await const BookmarkMetadataService().fetch(
                urlController.text,
              );
              await widget.repository.create(
                url: metadata.url,
                title: metadata.title,
                thumbnail: metadata.thumbnail,
                description: metadata.description,
                tagNames: _parseTags(tagsController.text),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              setDialogState(() => saving = false);
            }
          }

          return AlertDialog(
            title: const Text('ブックマークを追加'),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: urlController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        hintText: 'https://example.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'URLを入力してください'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText: 'タグ',
                        hintText: 'AI, 数学, 後で読む',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link),
                label: Text(saving ? '取得中…' : '追加'),
              ),
            ],
          );
        },
      ),
    );
    urlController.dispose();
    tagsController.dispose();
  }

  Future<void> _showEditDialog(BookmarkItem bookmark) async {
    final title = TextEditingController(text: bookmark.title);
    final url = TextEditingController(text: bookmark.url);
    final description = TextEditingController(text: bookmark.description ?? '');
    final thumbnail = TextEditingController(text: bookmark.thumbnail ?? '');
    final tagNames = TextEditingController(
      text: bookmark.tags.map((tag) => tag.name).join(', '),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ブックマークを編集'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'タイトル'),
                ),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '説明'),
                ),
                TextField(
                  controller: thumbnail,
                  decoration: const InputDecoration(labelText: 'サムネイルURL'),
                ),
                TextField(
                  controller: tagNames,
                  decoration: const InputDecoration(labelText: 'タグ'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.repository.update(
                id: bookmark.id,
                url: url.text.trim(),
                title: title.text.trim(),
                description:
                    description.text.trim().isEmpty ? null : description.text.trim(),
                thumbnail:
                    thumbnail.text.trim().isEmpty ? null : thumbnail.text.trim(),
                tagNames: _parseTags(tagNames.text),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    title.dispose();
    url.dispose();
    description.dispose();
    thumbnail.dispose();
    tagNames.dispose();
  }

  Future<void> _confirmDelete(BookmarkItem bookmark) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「${bookmark.title}」を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) await widget.repository.delete(bookmark.id);
  }

  Future<void> _saveCurrentView(List<Tag> tags) async {
    final nameController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('現在のビューを保存'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ビュー名',
            hintText: '例：数学のお気に入り',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await widget.repository.createSavedView(
                name: name,
                layoutType: _layoutName(_viewType),
                searchQuery: _query,
                favoritesOnly: _favoritesOnly,
                tagId: _selectedTagId,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    nameController.dispose();
  }

  void _applySavedView(SavedView view) {
    _searchController.text = view.searchQuery;
    setState(() {
      _activeSavedViewId = view.id;
      _query = view.searchQuery;
      _favoritesOnly = view.favoritesOnly;
      _selectedTagId = view.tagId;
      _viewType = _layoutFromName(view.layoutType);
    });
  }

  void _resetView() {
    _searchController.clear();
    setState(() {
      _activeSavedViewId = null;
      _query = '';
      _favoritesOnly = false;
      _selectedTagId = null;
      _viewType = BookmarkViewType.gallery;
    });
  }

  Future<void> _manageTags(List<Tag> tags) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('タグを管理'),
        content: SizedBox(
          width: 460,
          height: 420,
          child: tags.isEmpty
              ? const Center(child: Text('タグはまだありません'))
              : ListView.builder(
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return ListTile(
                      title: Text(tag.name),
                      subtitle: tag.parentTagId == null
                          ? null
                          : Text(
                              '親: ${tags.where((t) => t.id == tag.parentTagId).map((t) => t.name).firstOrNull ?? '不明'}',
                            ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'rename') {
                            final controller = TextEditingController(text: tag.name);
                            final newName = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('タグ名を変更'),
                                content: TextField(controller: controller),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('キャンセル'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(
                                      context,
                                      controller.text.trim(),
                                    ),
                                    child: const Text('変更'),
                                  ),
                                ],
                              ),
                            );
                            controller.dispose();
                            if (newName != null && newName.isNotEmpty) {
                              await widget.repository.renameTag(tag, newName);
                            }
                          } else if (value == 'delete') {
                            await widget.repository.deleteTag(tag);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('名前を変更')),
                          PopupMenuItem(value: 'delete', child: Text('削除')),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _bookmarkMenu(BookmarkItem bookmark) => PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'open') _openBookmark(bookmark);
          if (value == 'edit') _showEditDialog(bookmark);
          if (value == 'delete') _confirmDelete(bookmark);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'open', child: Text('開く')),
          PopupMenuItem(value: 'edit', child: Text('編集')),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      );

  Widget _gallery(List<BookmarkItem> bookmarks) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1100
              ? 5
              : constraints.maxWidth >= 800
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 3
                      : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .88,
            ),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openBookmark(bookmark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: bookmark.thumbnail == null
                              ? const Center(child: Icon(Icons.image_outlined, size: 46))
                              : Image.network(
                                  bookmark.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined, size: 46),
                                  ),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    bookmark.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => widget.repository.toggleFavorite(bookmark),
                                  icon: Icon(
                                    bookmark.favorite ? Icons.star : Icons.star_border,
                                  ),
                                ),
                                _bookmarkMenu(bookmark),
                              ],
                            ),
                            Text(
                              bookmark.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (bookmark.tags.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: bookmark.tags
                                    .take(4)
                                    .map(
                                      (tag) => ActionChip(
                                        label: Text(tag.name),
                                        onPressed: () => setState(() {
                                          _selectedTagId = tag.id;
                                          _activeSavedViewId = null;
                                        }),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

  Widget _list(List<BookmarkItem> bookmarks) => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: bookmarks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          return ListTile(
            onTap: () => _openBookmark(bookmark),
            leading: SizedBox(
              width: 72,
              child: bookmark.thumbnail == null
                  ? const Icon(Icons.bookmark_border)
                  : Image.network(bookmark.thumbnail!, fit: BoxFit.cover),
            ),
            title: Text(bookmark.title),
            subtitle: Text(
              [bookmark.url, ...bookmark.tags.map((tag) => tag.name)].join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => widget.repository.toggleFavorite(bookmark),
                  icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                ),
                _bookmarkMenu(bookmark),
              ],
            ),
          );
        },
      );

  Widget _table(List<BookmarkItem> bookmarks) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('タイトル')),
            DataColumn(label: Text('URL')),
            DataColumn(label: Text('タグ')),
            DataColumn(label: Text('★')),
            DataColumn(label: Text('操作')),
          ],
          rows: bookmarks
              .map(
                (bookmark) => DataRow(
                  cells: [
                    DataCell(SizedBox(width: 230, child: Text(bookmark.title))),
                    DataCell(SizedBox(width: 300, child: Text(bookmark.url))),
                    DataCell(Text(bookmark.tags.map((tag) => tag.name).join(', '))),
                    DataCell(
                      IconButton(
                        onPressed: () => widget.repository.toggleFavorite(bookmark),
                        icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                      ),
                    ),
                    DataCell(_bookmarkMenu(bookmark)),
                  ],
                ),
              )
              .toList(),
        ),
      );

  Widget _content(List<BookmarkItem> bookmarks) => switch (_viewType) {
        BookmarkViewType.gallery => _gallery(bookmarks),
        BookmarkViewType.list => _list(bookmarks),
        BookmarkViewType.table => _table(bookmarks),
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tag>>(
      stream: widget.repository.watchTags(),
      builder: (context, tagSnapshot) {
        final tags = tagSnapshot.data ?? const <Tag>[];
        return StreamBuilder<List<SavedView>>(
          stream: widget.repository.watchSavedViews(),
          builder: (context, viewSnapshot) {
            final savedViews = viewSnapshot.data ?? const <SavedView>[];
            return Scaffold(
              appBar: AppBar(
                title: const Text('Bookmarks'),
                actions: [
                  IconButton(
                    tooltip: '現在のビューを保存',
                    onPressed: () => _saveCurrentView(tags),
                    icon: const Icon(Icons.bookmark_add_outlined),
                  ),
                  PopupMenuButton<BookmarkViewType>(
                    tooltip: '表示形式',
                    initialValue: _viewType,
                    onSelected: (value) => setState(() {
                      _viewType = value;
                      _activeSavedViewId = null;
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: BookmarkViewType.gallery,
                        child: Text('Gallery'),
                      ),
                      PopupMenuItem(
                        value: BookmarkViewType.list,
                        child: Text('List'),
                      ),
                      PopupMenuItem(
                        value: BookmarkViewType.table,
                        child: Text('Table'),
                      ),
                    ],
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: _showAddBookmarkDialog,
                child: const Icon(Icons.add),
              ),
              body: Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          ListTile(
                            leading: const Icon(Icons.grid_view_outlined),
                            title: const Text('すべて'),
                            selected: _activeSavedViewId == null &&
                                _selectedTagId == null &&
                                !_favoritesOnly,
                            onTap: _resetView,
                          ),
                          ListTile(
                            leading: const Icon(Icons.star_outline),
                            title: const Text('お気に入り'),
                            selected: _favoritesOnly && _activeSavedViewId == null,
                            onTap: () => setState(() {
                              _favoritesOnly = !_favoritesOnly;
                              _activeSavedViewId = null;
                            }),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                            child: Row(
                              children: [
                                const Expanded(child: Text('保存ビュー')),
                                if (savedViews.isNotEmpty)
                                  const Icon(Icons.bookmarks_outlined, size: 18),
                              ],
                            ),
                          ),
                          ...savedViews.map(
                            (view) => ListTile(
                              dense: true,
                              title: Text(view.name),
                              selected: _activeSavedViewId == view.id,
                              onTap: () => _applySavedView(view),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 17),
                                onPressed: () => widget.repository.deleteSavedView(view.id),
                              ),
                            ),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                            child: Row(
                              children: [
                                const Expanded(child: Text('タグ')),
                                IconButton(
                                  tooltip: 'タグを管理',
                                  onPressed: () => _manageTags(tags),
                                  icon: const Icon(Icons.settings_outlined, size: 18),
                                ),
                              ],
                            ),
                          ),
                          ...tags.map(
                            (tag) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.sell_outlined, size: 17),
                              title: Text(tag.name),
                              selected: _selectedTagId == tag.id,
                              onTap: () => setState(() {
                                _selectedTagId = _selectedTagId == tag.id ? null : tag.id;
                                _activeSavedViewId = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) => setState(() {
                                    _query = value;
                                    _activeSavedViewId = null;
                                  }),
                                  decoration: InputDecoration(
                                    hintText: 'タイトル・URL・説明・タグを検索',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _query.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _query = '';
                                                _activeSavedViewId = null;
                                              });
                                            },
                                            icon: const Icon(Icons.clear),
                                          ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilterChip(
                                label: const Text('お気に入りのみ'),
                                selected: _favoritesOnly,
                                onSelected: (value) => setState(() {
                                  _favoritesOnly = value;
                                  _activeSavedViewId = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<BookmarkItem>>(
                            stream: widget.repository.watchAll(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final filtered = _filterBookmarks(snapshot.data!);
                              if (filtered.isEmpty) {
                                return const Center(child: Text('該当するブックマークがありません'));
                              }
                              return _content(filtered);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
