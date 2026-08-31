import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_metadata_service.dart';

enum BookmarkViewType { gallery, list, table }
enum TagMatchMode { or, and }
enum BookmarkSortField { createdAt, title, url }
enum SortDirection { asc, desc }

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
  TagMatchMode _tagMatchMode = TagMatchMode.or;
  BookmarkSortField _sortField = BookmarkSortField.createdAt;
  SortDirection _sortDirection = SortDirection.desc;
  final Set<int> _selectedTagIds = {};
  String _query = '';
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  BookmarkViewType _viewTypeFrom(String value) {
    return BookmarkViewType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => BookmarkViewType.gallery,
    );
  }

  TagMatchMode _matchModeFrom(String value) {
    return value == 'and' ? TagMatchMode.and : TagMatchMode.or;
  }

  BookmarkSortField _sortFieldFrom(String value) {
    return BookmarkSortField.values.firstWhere(
      (item) => item.name == value,
      orElse: () => BookmarkSortField.createdAt,
    );
  }

  SortDirection _sortDirectionFrom(String value) {
    return value == 'asc' ? SortDirection.asc : SortDirection.desc;
  }

  List<BookmarkItem> _filteredAndSorted(List<BookmarkItem> source) {
    final query = _query.trim().toLowerCase();
    var result = source.where((bookmark) {
      if (_favoritesOnly && !bookmark.favorite) return false;

      if (query.isNotEmpty) {
        final searchable = [
          bookmark.title,
          bookmark.url,
          bookmark.description ?? '',
          ...bookmark.tags.map((tag) => tag.name),
        ].join(' ').toLowerCase();
        if (!searchable.contains(query)) return false;
      }

      if (_selectedTagIds.isNotEmpty) {
        final bookmarkTagIds = bookmark.tags.map((tag) => tag.id).toSet();
        if (_tagMatchMode == TagMatchMode.and) {
          if (!_selectedTagIds.every(bookmarkTagIds.contains)) return false;
        } else {
          if (!_selectedTagIds.any(bookmarkTagIds.contains)) return false;
        }
      }

      return true;
    }).toList();

    int compare(BookmarkItem a, BookmarkItem b) {
      int value;
      switch (_sortField) {
        case BookmarkSortField.createdAt:
          value = a.createdAt.compareTo(b.createdAt);
        case BookmarkSortField.title:
          value = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case BookmarkSortField.url:
          value = a.url.toLowerCase().compareTo(b.url.toLowerCase());
      }
      return _sortDirection == SortDirection.asc ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _favoritesOnly = false;
      _selectedTagIds.clear();
      _tagMatchMode = TagMatchMode.or;
      _sortField = BookmarkSortField.createdAt;
      _sortDirection = SortDirection.desc;
    });
  }

  void _applySavedView(SavedViewConfig config) {
    final view = config.view;
    _searchController.text = view.searchQuery;
    setState(() {
      _query = view.searchQuery;
      _favoritesOnly = view.favoritesOnly;
      _viewType = _viewTypeFrom(view.layoutType);
      _tagMatchMode = _matchModeFrom(view.tagMatchMode);
      _sortField = _sortFieldFrom(view.sortField);
      _sortDirection = _sortDirectionFrom(view.sortDirection);
      _selectedTagIds
        ..clear()
        ..addAll(config.tags.map((tag) => tag.id));
    });
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

  List<String> _parseTags(String input) => input
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();

  Future<void> _showAddBookmarkDialog() async {
    final urlController = TextEditingController();
    final tagsController = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (saving || urlController.text.trim().isEmpty) return;
            setDialogState(() => saving = true);
            try {
              final metadata = await const BookmarkMetadataService()
                  .fetch(urlController.text.trim());
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => save(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'タグ（カンマ区切り）',
                      hintText: 'AI, 数学, 後で読む',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? '取得中…' : '追加'),
              ),
            ],
          );
        },
      ),
    );
    urlController.dispose();
    tagsController.dispose();
  }

  Future<void> _showEditBookmarkDialog(BookmarkItem bookmark) async {
    final title = TextEditingController(text: bookmark.title);
    final url = TextEditingController(text: bookmark.url);
    final description = TextEditingController(text: bookmark.description ?? '');
    final thumbnail = TextEditingController(text: bookmark.thumbnail ?? '');
    final tags = TextEditingController(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'タイトル')),
                TextField(controller: url, decoration: const InputDecoration(labelText: 'URL')),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: '説明')),
                TextField(controller: thumbnail, decoration: const InputDecoration(labelText: 'サムネイルURL')),
                TextField(controller: tags, decoration: const InputDecoration(labelText: 'タグ（カンマ区切り）')),
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
                description: description.text.trim().isEmpty ? null : description.text.trim(),
                thumbnail: thumbnail.text.trim().isEmpty ? null : thumbnail.text.trim(),
                tagNames: _parseTags(tags.text),
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
    tags.dispose();
  }

  Future<void> _deleteBookmark(BookmarkItem bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「${bookmark.title}」を削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed == true) await widget.repository.delete(bookmark.id);
  }

  Future<void> _saveCurrentView() async {
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('現在のビューを保存'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ビュー名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await widget.repository.createSavedView(
                name: name.text.trim(),
                layoutType: _viewType.name,
                searchQuery: _query,
                favoritesOnly: _favoritesOnly,
                tagIds: _selectedTagIds,
                tagMatchMode: _tagMatchMode.name,
                sortField: _sortField.name,
                sortDirection: _sortDirection.name,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    name.dispose();
  }

  Future<void> _editSavedView(SavedViewConfig config, List<Tag> allTags) async {
    final name = TextEditingController(text: config.view.name);
    var layout = _viewTypeFrom(config.view.layoutType);
    var favoritesOnly = config.view.favoritesOnly;
    var matchMode = _matchModeFrom(config.view.tagMatchMode);
    var sortField = _sortFieldFrom(config.view.sortField);
    var sortDirection = _sortDirectionFrom(config.view.sortDirection);
    final selected = config.tags.map((tag) => tag.id).toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('保存ビューを編集'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'ビュー名')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BookmarkViewType>(
                    initialValue: layout,
                    decoration: const InputDecoration(labelText: '表示形式'),
                    items: BookmarkViewType.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
                    onChanged: (v) => setDialogState(() => layout = v ?? layout),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('お気に入りのみ'),
                    value: favoritesOnly,
                    onChanged: (v) => setDialogState(() => favoritesOnly = v),
                  ),
                  const Text('タグ条件'),
                  const SizedBox(height: 6),
                  SegmentedButton<TagMatchMode>(
                    segments: const [
                      ButtonSegment(value: TagMatchMode.or, label: Text('OR')),
                      ButtonSegment(value: TagMatchMode.and, label: Text('AND')),
                    ],
                    selected: {matchMode},
                    onSelectionChanged: (value) => setDialogState(() => matchMode = value.first),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: allTags.map((tag) => FilterChip(
                      label: Text(tag.name),
                      selected: selected.contains(tag.id),
                      onSelected: (on) => setDialogState(() {
                        on ? selected.add(tag.id) : selected.remove(tag.id);
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<BookmarkSortField>(
                          initialValue: sortField,
                          decoration: const InputDecoration(labelText: '並び替え'),
                          items: BookmarkSortField.values.map((v) => DropdownMenuItem(value: v, child: Text(_sortFieldLabel(v)))).toList(),
                          onChanged: (v) => setDialogState(() => sortField = v ?? sortField),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<SortDirection>(
                          initialValue: sortDirection,
                          decoration: const InputDecoration(labelText: '順序'),
                          items: SortDirection.values.map((v) => DropdownMenuItem(value: v, child: Text(v == SortDirection.asc ? '昇順' : '降順'))).toList(),
                          onChanged: (v) => setDialogState(() => sortDirection = v ?? sortDirection),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await widget.repository.updateSavedView(
                  id: config.view.id,
                  name: name.text.trim(),
                  layoutType: layout.name,
                  searchQuery: config.view.searchQuery,
                  favoritesOnly: favoritesOnly,
                  tagIds: selected,
                  tagMatchMode: matchMode.name,
                  sortField: sortField.name,
                  sortDirection: sortDirection.name,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  static String _sortFieldLabel(BookmarkSortField field) {
    switch (field) {
      case BookmarkSortField.createdAt:
        return '登録日時';
      case BookmarkSortField.title:
        return 'タイトル';
      case BookmarkSortField.url:
        return 'URL';
    }
  }

  Widget _bookmarkMenu(BookmarkItem bookmark) => PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'open') _openBookmark(bookmark);
          if (value == 'edit') _showEditBookmarkDialog(bookmark);
          if (value == 'delete') _deleteBookmark(bookmark);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'open', child: Text('開く')),
          PopupMenuItem(value: 'edit', child: Text('編集')),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      );

  Widget _gallery(List<BookmarkItem> bookmarks) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1100 ? 5 : constraints.maxWidth >= 800 ? 4 : constraints.maxWidth >= 600 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
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
                              ? const Center(child: Icon(Icons.image_outlined, size: 48))
                              : Image.network(
                                  bookmark.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
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
                                Expanded(child: Text(bookmark.title, maxLines: 2, overflow: TextOverflow.ellipsis)),
                                IconButton(
                                  onPressed: () => widget.repository.toggleFavorite(bookmark),
                                  icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                                ),
                                _bookmarkMenu(bookmark),
                              ],
                            ),
                            Text(bookmark.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                            if (bookmark.tags.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: bookmark.tags.take(3).map((tag) => Chip(label: Text(tag.name), visualDensity: VisualDensity.compact)).toList(),
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
            title: Text(bookmark.title),
            subtitle: Text([bookmark.url, ...bookmark.tags.map((t) => t.name)].join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
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
            DataColumn(label: Text('お気に入り')),
            DataColumn(label: Text('操作')),
          ],
          rows: bookmarks.map((bookmark) => DataRow(cells: [
            DataCell(SizedBox(width: 220, child: Text(bookmark.title, overflow: TextOverflow.ellipsis)), onTap: () => _openBookmark(bookmark)),
            DataCell(SizedBox(width: 300, child: Text(bookmark.url, overflow: TextOverflow.ellipsis)), onTap: () => _openBookmark(bookmark)),
            DataCell(Text(bookmark.tags.map((t) => t.name).join(', '))),
            DataCell(IconButton(onPressed: () => widget.repository.toggleFavorite(bookmark), icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border))),
            DataCell(_bookmarkMenu(bookmark)),
          ])).toList(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tag>>(
      stream: widget.repository.watchTags(),
      builder: (context, tagSnapshot) {
        final allTags = tagSnapshot.data ?? const <Tag>[];
        return StreamBuilder<List<SavedViewConfig>>(
          stream: widget.repository.watchSavedViews(),
          builder: (context, viewSnapshot) {
            final savedViews = viewSnapshot.data ?? const <SavedViewConfig>[];
            return Scaffold(
              appBar: AppBar(
                title: const Text('Bookmarks'),
                actions: [
                  IconButton(onPressed: _saveCurrentView, tooltip: '現在のビューを保存', icon: const Icon(Icons.bookmark_add_outlined)),
                  const SizedBox(width: 8),
                ],
              ),
              floatingActionButton: FloatingActionButton(onPressed: _showAddBookmarkDialog, child: const Icon(Icons.add)),
              body: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        ListTile(leading: const Icon(Icons.all_inbox), title: const Text('すべて'), onTap: _resetFilters),
                        ListTile(
                          leading: const Icon(Icons.star_outline),
                          title: const Text('お気に入り'),
                          selected: _favoritesOnly,
                          onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
                        ),
                        const Divider(),
                        const Padding(padding: EdgeInsets.all(8), child: Text('保存ビュー')),
                        ...savedViews.map((config) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.view_quilt_outlined),
                              title: Text(config.view.name),
                              onTap: () => _applySavedView(config),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _editSavedView(config, allTags);
                                  if (value == 'delete') widget.repository.deleteSavedView(config.view.id);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('編集')),
                                  PopupMenuItem(value: 'delete', child: Text('削除')),
                                ],
                              ),
                            )),
                        const Divider(),
                        const Padding(padding: EdgeInsets.all(8), child: Text('タグ')),
                        ...allTags.map((tag) => CheckboxListTile(
                              dense: true,
                              value: _selectedTagIds.contains(tag.id),
                              title: Text(tag.name),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (on) => setState(() {
                                on == true ? _selectedTagIds.add(tag.id) : _selectedTagIds.remove(tag.id);
                              }),
                            )),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 280,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) => setState(() => _query = value),
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '検索', border: OutlineInputBorder(), isDense: true),
                                ),
                              ),
                              SegmentedButton<TagMatchMode>(
                                segments: const [
                                  ButtonSegment(value: TagMatchMode.or, label: Text('タグ OR')),
                                  ButtonSegment(value: TagMatchMode.and, label: Text('タグ AND')),
                                ],
                                selected: {_tagMatchMode},
                                onSelectionChanged: (value) => setState(() => _tagMatchMode = value.first),
                              ),
                              DropdownButton<BookmarkSortField>(
                                value: _sortField,
                                items: BookmarkSortField.values.map((v) => DropdownMenuItem(value: v, child: Text(_sortFieldLabel(v)))).toList(),
                                onChanged: (v) => setState(() => _sortField = v ?? _sortField),
                              ),
                              IconButton(
                                tooltip: _sortDirection == SortDirection.asc ? '昇順' : '降順',
                                onPressed: () => setState(() => _sortDirection = _sortDirection == SortDirection.asc ? SortDirection.desc : SortDirection.asc),
                                icon: Icon(_sortDirection == SortDirection.asc ? Icons.arrow_upward : Icons.arrow_downward),
                              ),
                              SegmentedButton<BookmarkViewType>(
                                segments: const [
                                  ButtonSegment(value: BookmarkViewType.gallery, icon: Icon(Icons.grid_view)),
                                  ButtonSegment(value: BookmarkViewType.list, icon: Icon(Icons.view_list)),
                                  ButtonSegment(value: BookmarkViewType.table, icon: Icon(Icons.table_rows)),
                                ],
                                selected: {_viewType},
                                onSelectionChanged: (value) => setState(() => _viewType = value.first),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: StreamBuilder<List<BookmarkItem>>(
                            stream: widget.repository.watchAll(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                              final bookmarks = _filteredAndSorted(snapshot.data!);
                              if (bookmarks.isEmpty) return const Center(child: Text('条件に一致するブックマークがありません'));
                              switch (_viewType) {
                                case BookmarkViewType.gallery:
                                  return _gallery(bookmarks);
                                case BookmarkViewType.list:
                                  return _list(bookmarks);
                                case BookmarkViewType.table:
                                  return _table(bookmarks);
                              }
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
