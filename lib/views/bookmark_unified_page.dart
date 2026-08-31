import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../widgets/bookmark_create_dialog.dart';
import '../widgets/bookmark_detail_panel.dart';

enum BookmarkViewType { gallery, list, table }
enum TagMatchMode { or, and }
enum BookmarkSortField { createdAt, title, url }
enum SortDirection { asc, desc }

class BookmarkUnifiedPage extends StatefulWidget {
  const BookmarkUnifiedPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<BookmarkUnifiedPage> createState() => _BookmarkUnifiedPageState();
}

class _BookmarkUnifiedPageState extends State<BookmarkUnifiedPage> {
  final _searchController = TextEditingController();
  final Set<int> _selectedTagIds = {};

  BookmarkViewType _viewType = BookmarkViewType.gallery;
  TagMatchMode _tagMatchMode = TagMatchMode.or;
  BookmarkSortField _sortField = BookmarkSortField.createdAt;
  SortDirection _sortDirection = SortDirection.desc;
  String _query = '';
  bool _favoritesOnly = false;
  bool _includeDescendants = true;
  int? _activeSavedViewId;
  int? _selectedBookmarkId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  BookmarkViewType _parseViewType(String value) =>
      BookmarkViewType.values.where((e) => e.name == value).firstOrNull ?? BookmarkViewType.gallery;
  BookmarkSortField _parseSortField(String value) =>
      BookmarkSortField.values.where((e) => e.name == value).firstOrNull ?? BookmarkSortField.createdAt;
  TagMatchMode _parseMatchMode(String value) => value == 'and' ? TagMatchMode.and : TagMatchMode.or;
  SortDirection _parseSortDirection(String value) => value == 'asc' ? SortDirection.asc : SortDirection.desc;

  static String _sortLabel(BookmarkSortField field) => switch (field) {
        BookmarkSortField.createdAt => '登録日時',
        BookmarkSortField.title => 'タイトル',
        BookmarkSortField.url => 'URL',
      };

  List<Tag> _childrenOf(int? parentId, List<Tag> tags) => tags
      .where((tag) => tag.parentTagId == parentId)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Set<int> _descendantIds(int tagId, List<Tag> tags) {
    final result = <int>{};
    void visit(int parentId) {
      for (final child in tags.where((tag) => tag.parentTagId == parentId)) {
        if (result.add(child.id)) visit(child.id);
      }
    }
    visit(tagId);
    return result;
  }

  List<BookmarkItem> _applyFilters(List<BookmarkItem> source, List<Tag> allTags) {
    final query = _query.trim().toLowerCase();
    final result = source.where((bookmark) {
      if (_favoritesOnly && !bookmark.favorite) return false;
      if (query.isNotEmpty) {
        final text = [
          bookmark.title,
          bookmark.url,
          bookmark.description ?? '',
          ...bookmark.tags.map((tag) => tag.name),
          ...bookmark.people.map((person) => person.name),
        ].join(' ').toLowerCase();
        if (!text.contains(query)) return false;
      }
      if (_selectedTagIds.isNotEmpty) {
        final bookmarkTagIds = bookmark.tags.map((tag) => tag.id).toSet();
        bool match;
        if (_tagMatchMode == TagMatchMode.or) {
          final allowed = <int>{};
          for (final id in _selectedTagIds) {
            allowed.add(id);
            if (_includeDescendants) allowed.addAll(_descendantIds(id, allTags));
          }
          match = allowed.any(bookmarkTagIds.contains);
        } else {
          match = _selectedTagIds.every((id) {
            final allowed = <int>{id};
            if (_includeDescendants) allowed.addAll(_descendantIds(id, allTags));
            return allowed.any(bookmarkTagIds.contains);
          });
        }
        if (!match) return false;
      }
      return true;
    }).toList();

    int compare(BookmarkItem a, BookmarkItem b) {
      final value = switch (_sortField) {
        BookmarkSortField.createdAt => a.createdAt.compareTo(b.createdAt),
        BookmarkSortField.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        BookmarkSortField.url => a.url.toLowerCase().compareTo(b.url.toLowerCase()),
      };
      return _sortDirection == SortDirection.asc ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _selectBookmark(BookmarkItem bookmark) => setState(() => _selectedBookmarkId = bookmark.id);

  Future<void> _openBookmark(BookmarkItem bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
    }
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
    if (confirmed == true) {
      await widget.repository.delete(bookmark.id);
      if (_selectedBookmarkId == bookmark.id) setState(() => _selectedBookmarkId = null);
    }
  }

  Widget _bookmarkMenu(BookmarkItem bookmark) => PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'details') _selectBookmark(bookmark);
          if (value == 'open') _openBookmark(bookmark);
          if (value == 'delete') _deleteBookmark(bookmark);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'details', child: Text('詳細を表示')),
          PopupMenuItem(value: 'open', child: Text('ブラウザで開く')),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      );

  Widget _placeholder(double size) => Center(child: Icon(Icons.image_outlined, size: size));

  Widget _image(BookmarkItem bookmark, {double? width, double? height, double placeholderSize = 44}) {
    if (bookmark.coverPhoto != null) {
      return Image.file(
        File(bookmark.coverPhoto!.path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _networkImage(bookmark, width, height, placeholderSize),
      );
    }
    return _networkImage(bookmark, width, height, placeholderSize);
  }

  Widget _networkImage(BookmarkItem bookmark, double? width, double? height, double placeholderSize) {
    if (bookmark.thumbnail?.trim().isNotEmpty != true) {
      return SizedBox(width: width, height: height, child: _placeholder(placeholderSize));
    }
    return Image.network(
      bookmark.thumbnail!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => SizedBox(width: width, height: height, child: _placeholder(placeholderSize)),
    );
  }

  Widget _gallery(List<BookmarkItem> bookmarks) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1050
              ? 4
              : constraints.maxWidth >= 780
                  ? 3
                  : 2;
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
              final selected = bookmark.id == _selectedBookmarkId;
              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: selected ? 3 : 1,
                child: InkWell(
                  onTap: () => _selectBookmark(bookmark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SizedBox(width: double.infinity, child: _image(bookmark))),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(bookmark.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleSmall),
                                ),
                                IconButton(
                                  tooltip: 'お気に入り',
                                  onPressed: () => widget.repository.toggleFavorite(bookmark),
                                  icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                                ),
                                _bookmarkMenu(bookmark),
                              ],
                            ),
                            Text(bookmark.url, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall),
                            if (bookmark.tags.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: bookmark.tags.take(3).map((tag) => Chip(
                                      label: Text(tag.name),
                                      visualDensity: VisualDensity.compact,
                                    )).toList(),
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
            selected: bookmark.id == _selectedBookmarkId,
            onTap: () => _selectBookmark(bookmark),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(width: 56, height: 42, child: _image(bookmark, width: 56, height: 42, placeholderSize: 24)),
            ),
            title: Text(bookmark.title),
            subtitle: Text([bookmark.url, ...bookmark.tags.map((e) => e.name)].join(' • '),
                maxLines: 2, overflow: TextOverflow.ellipsis),
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
            DataColumn(label: Text('画像')),
            DataColumn(label: Text('タイトル')),
            DataColumn(label: Text('URL')),
            DataColumn(label: Text('タグ')),
            DataColumn(label: Text('お気に入り')),
            DataColumn(label: Text('操作')),
          ],
          rows: bookmarks.map((bookmark) => DataRow(
                selected: bookmark.id == _selectedBookmarkId,
                onSelectChanged: (_) => _selectBookmark(bookmark),
                cells: [
                  DataCell(ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(width: 64, height: 42, child: _image(bookmark, width: 64, height: 42, placeholderSize: 22)),
                  )),
                  DataCell(Text(bookmark.title)),
                  DataCell(Text(bookmark.url)),
                  DataCell(Text(bookmark.tags.map((e) => e.name).join(', '))),
                  DataCell(IconButton(
                    onPressed: () => widget.repository.toggleFavorite(bookmark),
                    icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                  )),
                  DataCell(_bookmarkMenu(bookmark)),
                ],
              )).toList(),
        ),
      );

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _activeSavedViewId = null;
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
      _activeSavedViewId = view.id;
      _query = view.searchQuery;
      _favoritesOnly = view.favoritesOnly;
      _viewType = _parseViewType(view.layoutType);
      _tagMatchMode = _parseMatchMode(view.tagMatchMode);
      _sortField = _parseSortField(view.sortField);
      _sortDirection = _parseSortDirection(view.sortDirection);
      _selectedTagIds
        ..clear()
        ..addAll(config.tags.map((tag) => tag.id));
    });
  }

  Future<void> _saveCurrentView() async {
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('現在のビューを保存'),
        content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'ビュー名')),
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

  Future<void> _showFilterDialog(List<Tag> allTags) async {
    var favorites = _favoritesOnly;
    var matchMode = _tagMatchMode;
    var includeDescendants = _includeDescendants;
    final selectedTags = {..._selectedTagIds};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('フィルター'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('お気に入りのみ'),
                    value: favorites,
                    onChanged: (value) => setLocalState(() => favorites = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('子タグも含める'),
                    value: includeDescendants,
                    onChanged: (value) => setLocalState(() => includeDescendants = value),
                  ),
                  Row(
                    children: [
                      const Text('タグ条件'),
                      const Spacer(),
                      SegmentedButton<TagMatchMode>(
                        segments: const [
                          ButtonSegment(value: TagMatchMode.or, label: Text('OR')),
                          ButtonSegment(value: TagMatchMode.and, label: Text('AND')),
                        ],
                        selected: {matchMode},
                        onSelectionChanged: (value) => setLocalState(() => matchMode = value.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allTags.map((tag) => FilterChip(
                          label: Text(tag.name),
                          selected: selectedTags.contains(tag.id),
                          onSelected: (selected) => setLocalState(() {
                            if (selected) {
                              selectedTags.add(tag.id);
                            } else {
                              selectedTags.remove(tag.id);
                            }
                          }),
                        )).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _favoritesOnly = favorites;
                  _tagMatchMode = matchMode;
                  _includeDescendants = includeDescendants;
                  _selectedTagIds
                    ..clear()
                    ..addAll(selectedTags);
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('適用'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(List<Tag> allTags) {
    final filterCount = (_favoritesOnly ? 1 : 0) + _selectedTagIds.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'このデータベースを検索…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            child: OutlinedButton.icon(
              onPressed: () => _showFilterDialog(allTags),
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('フィルター'),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<BookmarkSortField>(
            initialValue: _sortField,
            onSelected: (value) => setState(() => _sortField = value),
            itemBuilder: (_) => BookmarkSortField.values.map((field) => PopupMenuItem(
                  value: field,
                  child: Text(_sortLabel(field)),
                )).toList(),
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.swap_vert, size: 18),
              label: Text(_sortLabel(_sortField)),
            ),
          ),
          IconButton(
            tooltip: _sortDirection == SortDirection.asc ? '昇順' : '降順',
            onPressed: () => setState(() => _sortDirection = _sortDirection == SortDirection.asc ? SortDirection.desc : SortDirection.asc),
            icon: Icon(_sortDirection == SortDirection.asc ? Icons.arrow_upward : Icons.arrow_downward),
          ),
          SegmentedButton<BookmarkViewType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: BookmarkViewType.gallery, icon: Icon(Icons.grid_view, size: 18)),
              ButtonSegment(value: BookmarkViewType.list, icon: Icon(Icons.view_list, size: 18)),
              ButtonSegment(value: BookmarkViewType.table, icon: Icon(Icons.table_rows, size: 18)),
            ],
            selected: {_viewType},
            onSelectionChanged: (value) => setState(() => _viewType = value.first),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saveCurrentView,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('ビューを保存'),
          ),
        ],
      ),
    );
  }

  Widget _tagTree(List<Tag> allTags, int? parentId, int depth) {
    final children = _childrenOf(parentId, allTags);
    return Column(
      children: children.map((tag) {
        final nested = _childrenOf(tag.id, allTags);
        return Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.only(left: 8 + depth * 18, right: 6),
              leading: Icon(nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined, size: 18),
              title: Text(tag.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              selected: _selectedTagIds.length == 1 && _selectedTagIds.contains(tag.id),
              onTap: () {
                _searchController.clear();
                setState(() {
                  _activeSavedViewId = null;
                  _query = '';
                  _favoritesOnly = false;
                  _selectedTagIds
                    ..clear()
                    ..add(tag.id);
                });
              },
            ),
            if (nested.isNotEmpty) _tagTree(allTags, tag.id, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _sidebar(List<Tag> allTags, List<SavedViewConfig> savedViews) => Container(
        width: 220,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.all_inbox_outlined),
              title: const Text('すべて'),
              onTap: _resetFilters,
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.star_outline),
              title: const Text('お気に入り'),
              selected: _favoritesOnly && _selectedTagIds.isEmpty,
              onTap: () {
                _searchController.clear();
                setState(() {
                  _activeSavedViewId = null;
                  _query = '';
                  _favoritesOnly = true;
                  _selectedTagIds.clear();
                });
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text('保存ビュー', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...savedViews.map((config) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.view_quilt_outlined, size: 19),
                  title: Text(config.view.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  selected: _activeSavedViewId == config.view.id,
                  onTap: () => _applySavedView(config),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 15),
                    onPressed: () => widget.repository.deleteSavedView(config.view.id),
                  ),
                )),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
              child: Row(
                children: [
                  const Expanded(child: Text('タグ', style: TextStyle(fontWeight: FontWeight.w600))),
                  Switch(value: _includeDescendants, onChanged: (v) => setState(() => _includeDescendants = v)),
                ],
              ),
            ),
            _tagTree(allTags, null, 0),
          ],
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
                title: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmarks_outlined, size: 22),
                    SizedBox(width: 8),
                    Text('Bookmarks'),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => showBookmarkCreateDialog(context: context, repository: widget.repository),
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
              body: StreamBuilder<List<BookmarkItem>>(
                stream: widget.repository.watchAll(),
                builder: (context, bookmarkSnapshot) {
                  if (!bookmarkSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final allBookmarks = bookmarkSnapshot.data!;
                  final bookmarks = _applyFilters(allBookmarks, allTags);
                  final selected = allBookmarks.where((b) => b.id == _selectedBookmarkId).firstOrNull;

                  return Row(
                    children: [
                      _sidebar(allTags, savedViews),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Column(
                          children: [
                            _toolbar(allTags),
                            Expanded(
                              child: bookmarks.isEmpty
                                  ? const Center(child: Text('条件に一致するブックマークがありません'))
                                  : switch (_viewType) {
                                      BookmarkViewType.gallery => _gallery(bookmarks),
                                      BookmarkViewType.list => _list(bookmarks),
                                      BookmarkViewType.table => _table(bookmarks),
                                    },
                            ),
                          ],
                        ),
                      ),
                      if (selected != null) ...[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 430,
                          child: BookmarkDetailPanel(
                            key: ValueKey(selected.id),
                            repository: widget.repository,
                            bookmark: selected,
                            onClose: () => setState(() => _selectedBookmarkId = null),
                          ),
                        ),
                      ],
                    ],
                  );
                },
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
