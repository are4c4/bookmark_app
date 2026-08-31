import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_metadata_service.dart';

enum BookmarkViewType { gallery, list, table }
enum TagMatchMode { or, and }
enum BookmarkSortField { createdAt, title, url }
enum SortDirection { asc, desc }

class BookmarkWorkspacePage extends StatefulWidget {
  const BookmarkWorkspacePage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<BookmarkWorkspacePage> createState() => _BookmarkWorkspacePageState();
}

class _BookmarkWorkspacePageState extends State<BookmarkWorkspacePage> {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  BookmarkViewType _parseViewType(String value) =>
      BookmarkViewType.values.where((e) => e.name == value).firstOrNull ??
      BookmarkViewType.gallery;

  BookmarkSortField _parseSortField(String value) =>
      BookmarkSortField.values.where((e) => e.name == value).firstOrNull ??
      BookmarkSortField.createdAt;

  TagMatchMode _parseMatchMode(String value) =>
      value == 'and' ? TagMatchMode.and : TagMatchMode.or;

  SortDirection _parseSortDirection(String value) =>
      value == 'asc' ? SortDirection.asc : SortDirection.desc;

  static String _sortLabel(BookmarkSortField field) => switch (field) {
        BookmarkSortField.createdAt => '登録日時',
        BookmarkSortField.title => 'タイトル',
        BookmarkSortField.url => 'URL',
      };

  List<String> _parseTagNames(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

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

  Set<int> _effectiveTagIds(List<Tag> allTags) {
    if (!_includeDescendants) return {..._selectedTagIds};
    final result = <int>{..._selectedTagIds};
    for (final id in _selectedTagIds) {
      result.addAll(_descendantIds(id, allTags));
    }
    return result;
  }

  List<BookmarkItem> _applyFilters(
    List<BookmarkItem> source,
    List<Tag> allTags,
  ) {
    final query = _query.trim().toLowerCase();
    final effectiveTagIds = _effectiveTagIds(allTags);
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
        final ids = bookmark.tags.map((tag) => tag.id).toSet();
        final matches = _tagMatchMode == TagMatchMode.or
            ? effectiveTagIds.any(ids.contains)
            : _selectedTagIds.every((selectedId) {
                final allowed = <int>{selectedId};
                if (_includeDescendants) {
                  allowed.addAll(_descendantIds(selectedId, allTags));
                }
                return allowed.any(ids.contains);
              });
        if (!matches) return false;
      }
      return true;
    }).toList();

    int compare(BookmarkItem a, BookmarkItem b) {
      final value = switch (_sortField) {
        BookmarkSortField.createdAt => a.createdAt.compareTo(b.createdAt),
        BookmarkSortField.title =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        BookmarkSortField.url =>
          a.url.toLowerCase().compareTo(b.url.toLowerCase()),
      };
      return _sortDirection == SortDirection.asc ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  Widget _imagePlaceholder({double iconSize = 48}) => Center(
        child: Icon(Icons.image_outlined, size: iconSize),
      );

  Widget _bookmarkImage(
    BookmarkItem bookmark, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    double placeholderIconSize = 48,
  }) {
    final cover = bookmark.coverPhoto;
    if (cover != null) {
      return Image.file(
        File(cover.path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            _networkOrPlaceholder(bookmark, fit, width, height, placeholderIconSize),
      );
    }
    return _networkOrPlaceholder(
      bookmark,
      fit,
      width,
      height,
      placeholderIconSize,
    );
  }

  Widget _networkOrPlaceholder(
    BookmarkItem bookmark,
    BoxFit fit,
    double? width,
    double? height,
    double placeholderIconSize,
  ) {
    final thumbnail = bookmark.thumbnail;
    if (thumbnail == null || thumbnail.trim().isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: _imagePlaceholder(iconSize: placeholderIconSize),
      );
    }
    return Image.network(
      thumbnail,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: _imagePlaceholder(iconSize: placeholderIconSize),
      ),
    );
  }

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

  Future<void> _addBookmark() async {
    final url = TextEditingController();
    final tags = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          Future<void> save() async {
            if (saving || url.text.trim().isEmpty) return;
            setLocalState(() => saving = true);
            try {
              final metadata = await const BookmarkMetadataService()
                  .fetch(url.text.trim());
              await widget.repository.create(
                url: metadata.url,
                title: metadata.title,
                thumbnail: metadata.thumbnail,
                description: metadata.description,
                tagNames: _parseTagNames(tags.text),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              setLocalState(() => saving = false);
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
                    controller: url,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => save(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'タグ（カンマ区切り）',
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
    url.dispose();
    tags.dispose();
  }

  Future<void> _editBookmark(BookmarkItem bookmark) async {
    final title = TextEditingController(text: bookmark.title);
    final url = TextEditingController(text: bookmark.url);
    final description = TextEditingController(text: bookmark.description ?? '');
    final thumbnail = TextEditingController(text: bookmark.thumbnail ?? '');
    final tags = TextEditingController(
      text: bookmark.tags.map((e) => e.name).join(', '),
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
                  decoration: const InputDecoration(labelText: 'WebサムネイルURL'),
                ),
                TextField(
                  controller: tags,
                  decoration: const InputDecoration(labelText: 'タグ（カンマ区切り）'),
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
                description: description.text.trim().isEmpty
                    ? null
                    : description.text.trim(),
                thumbnail: thumbnail.text.trim().isEmpty
                    ? null
                    : thumbnail.text.trim(),
                tagNames: _parseTagNames(tags.text),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
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
                    subtitle: const Text('親タグを選択したとき、配下のタグも検索対象にします'),
                    value: includeDescendants,
                    onChanged: (value) =>
                        setLocalState(() => includeDescendants = value),
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
                        onSelectionChanged: (value) =>
                            setLocalState(() => matchMode = value.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allTags
                        .map((tag) => FilterChip(
                              label: Text(tag.name),
                              selected: selectedTags.contains(tag.id),
                              onSelected: (selected) => setLocalState(() {
                                if (selected) {
                                  selectedTags.add(tag.id);
                                } else {
                                  selectedTags.remove(tag.id);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setLocalState(() {
                  favorites = false;
                  selectedTags.clear();
                  matchMode = TagMatchMode.or;
                  includeDescendants = true;
                });
              },
              child: const Text('クリア'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
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

  Widget _bookmarkMenu(BookmarkItem bookmark) => PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'open') _openBookmark(bookmark);
          if (value == 'edit') _editBookmark(bookmark);
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
          final columns = constraints.maxWidth >= 1100
              ? 5
              : constraints.maxWidth >= 820
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
                          child: _bookmarkImage(bookmark),
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
                                  tooltip: 'お気に入り',
                                  onPressed: () =>
                                      widget.repository.toggleFavorite(bookmark),
                                  icon: Icon(
                                    bookmark.favorite
                                        ? Icons.star
                                        : Icons.star_border,
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
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: bookmark.tags
                                    .take(3)
                                    .map((tag) => Chip(
                                          label: Text(tag.name),
                                          visualDensity: VisualDensity.compact,
                                        ))
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
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 42,
                child: _bookmarkImage(
                  bookmark,
                  width: 56,
                  height: 42,
                  placeholderIconSize: 24,
                ),
              ),
            ),
            title: Text(bookmark.title),
            subtitle: Text(
              [bookmark.url, ...bookmark.tags.map((e) => e.name)].join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => widget.repository.toggleFavorite(bookmark),
                  icon: Icon(
                    bookmark.favorite ? Icons.star : Icons.star_border,
                  ),
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
          rows: bookmarks
              .map((bookmark) => DataRow(cells: [
                    DataCell(
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 64,
                          height: 42,
                          child: _bookmarkImage(
                            bookmark,
                            width: 64,
                            height: 42,
                            placeholderIconSize: 22,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(bookmark.title),
                      onTap: () => _openBookmark(bookmark),
                    ),
                    DataCell(
                      Text(bookmark.url),
                      onTap: () => _openBookmark(bookmark),
                    ),
                    DataCell(
                      Text(bookmark.tags.map((e) => e.name).join(', ')),
                    ),
                    DataCell(IconButton(
                      onPressed: () => widget.repository.toggleFavorite(bookmark),
                      icon: Icon(
                        bookmark.favorite ? Icons.star : Icons.star_border,
                      ),
                    )),
                    DataCell(_bookmarkMenu(bookmark)),
                  ]))
              .toList(),
        ),
      );

  Widget _toolbar(List<Tag> allTags) {
    final filterCount = (_favoritesOnly ? 1 : 0) + _selectedTagIds.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
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
            itemBuilder: (_) => BookmarkSortField.values
                .map((field) => PopupMenuItem(
                      value: field,
                      child: Row(
                        children: [
                          if (_sortField == field)
                            const Icon(Icons.check, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(_sortLabel(field)),
                        ],
                      ),
                    ))
                .toList(),
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.swap_vert, size: 18),
              label: Text(_sortLabel(_sortField)),
            ),
          ),
          IconButton(
            tooltip: _sortDirection == SortDirection.asc ? '昇順' : '降順',
            onPressed: () => setState(() {
              _sortDirection = _sortDirection == SortDirection.asc
                  ? SortDirection.desc
                  : SortDirection.asc;
            }),
            icon: Icon(
              _sortDirection == SortDirection.asc
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 6),
          SegmentedButton<BookmarkViewType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: BookmarkViewType.gallery,
                icon: Icon(Icons.grid_view, size: 18),
              ),
              ButtonSegment(
                value: BookmarkViewType.list,
                icon: Icon(Icons.view_list, size: 18),
              ),
              ButtonSegment(
                value: BookmarkViewType.table,
                icon: Icon(Icons.table_rows, size: 18),
              ),
            ],
            selected: {_viewType},
            onSelectionChanged: (value) =>
                setState(() => _viewType = value.first),
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

  Widget _tagTreeSidebar(
    List<Tag> allTags,
    int? parentId,
    int depth,
  ) {
    final children = _childrenOf(parentId, allTags);
    return Column(
      children: children.map((tag) {
        final nested = _childrenOf(tag.id, allTags);
        final selected = _selectedTagIds.length == 1 &&
            _selectedTagIds.contains(tag.id);
        return Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.only(
                left: 8 + depth * 18,
                right: 6,
              ),
              leading: Icon(
                nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined,
                size: 18,
              ),
              title: Text(
                tag.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: selected,
              onTap: () {
                _searchController.clear();
                setState(() {
                  _activeSavedViewId = null;
                  _query = '';
                  _favoritesOnly = false;
                  _selectedTagIds
                    ..clear()
                    ..add(tag.id);
                  _tagMatchMode = TagMatchMode.or;
                });
              },
            ),
            if (nested.isNotEmpty)
              _tagTreeSidebar(allTags, tag.id, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _sidebar(List<Tag> allTags, List<SavedViewConfig> savedViews) {
    return Container(
      width: 240,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.all_inbox_outlined),
            title: const Text('すべて'),
            selected: _activeSavedViewId == null &&
                !_favoritesOnly &&
                _selectedTagIds.isEmpty,
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
          const SizedBox(height: 8),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Text(
              '保存ビュー',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (savedViews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('まだありません', style: TextStyle(fontSize: 12)),
            ),
          ...savedViews.map((config) => ListTile(
                dense: true,
                leading: const Icon(Icons.view_quilt_outlined, size: 20),
                title: Text(
                  config.view.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: _activeSavedViewId == config.view.id,
                onTap: () => _applySavedView(config),
                trailing: IconButton(
                  tooltip: '削除',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () =>
                      widget.repository.deleteSavedView(config.view.id),
                ),
              )),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'タグ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Tooltip(
                  message: _includeDescendants
                      ? '子タグを含めています'
                      : '選択したタグだけを対象にします',
                  child: Switch(
                    value: _includeDescendants,
                    onChanged: (value) =>
                        setState(() => _includeDescendants = value),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
            child: Text(
              _includeDescendants ? '子タグも含める' : '親タグだけ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _tagTreeSidebar(allTags, null, 0),
        ],
      ),
    );
  }

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
                titleSpacing: 16,
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
                onPressed: _addBookmark,
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
              body: Row(
                children: [
                  _sidebar(allTags, savedViews),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        _toolbar(allTags),
                        Expanded(
                          child: StreamBuilder<List<BookmarkItem>>(
                            stream: widget.repository.watchAll(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final bookmarks =
                                  _applyFilters(snapshot.data!, allTags);
                              if (bookmarks.isEmpty) {
                                return const Center(
                                  child: Text('条件に一致するブックマークがありません'),
                                );
                              }
                              return switch (_viewType) {
                                BookmarkViewType.gallery => _gallery(bookmarks),
                                BookmarkViewType.list => _list(bookmarks),
                                BookmarkViewType.table => _table(bookmarks),
                              };
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

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
