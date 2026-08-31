import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../widgets/bookmark_create_dialog.dart';
import '../widgets/bookmark_detail_panel.dart';
import '../widgets/notion_bookmark_card.dart';
import '../widgets/relation_database_picker.dart';

enum BookmarkViewType { gallery, list, table }
enum TagMatchMode { or, and }
enum BookmarkSortField { createdAt, title, url }
enum SortDirection { asc, desc }
enum ViewProperty { image, url, tags, people, description, createdAt, favorite, status, rating, history }

const _statusLabels = <String, String>{
  'unread': '未読',
  'later': '後で見る',
  'in_progress': '閲覧中 / 視聴中',
  'done': '完了 / 視聴済み',
  'archived': 'アーカイブ',
};

class BookmarkUnifiedPage extends StatefulWidget {
  const BookmarkUnifiedPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<BookmarkUnifiedPage> createState() => _BookmarkUnifiedPageState();
}

class _BookmarkUnifiedPageState extends State<BookmarkUnifiedPage> {
  final _searchController = TextEditingController();
  final Set<int> _selectedTagIds = {};
  final Set<int> _batchSelectedIds = {};
  final Set<ViewProperty> _visibleProperties = {
    ViewProperty.image,
    ViewProperty.url,
    ViewProperty.tags,
    ViewProperty.favorite,
  };

  BookmarkViewType _viewType = BookmarkViewType.gallery;
  TagMatchMode _tagMatchMode = TagMatchMode.or;
  BookmarkSortField _sortField = BookmarkSortField.createdAt;
  SortDirection _sortDirection = SortDirection.desc;
  String _query = '';
  bool _favoritesOnly = false;
  bool _includeDescendants = true;
  bool _selectionMode = false;
  bool _sidebarCollapsed = false;
  String _statusFilter = '';
  int _minRating = 0;
  int? _activeSavedViewId;
  int? _selectedBookmarkId;
  int? _personFilterId;
  int? _photoFilterId;
  String? _relationFilterLabel;
  double _detailWidth = 430;

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

  Set<ViewProperty> _parseVisibleProperties(String value) {
    final names = value.split(',').map((e) => e.trim()).toSet();
    final parsed = ViewProperty.values.where((property) => names.contains(property.name)).toSet();
    return parsed.isEmpty
        ? {ViewProperty.image, ViewProperty.url, ViewProperty.tags, ViewProperty.favorite}
        : parsed;
  }

  String get _visiblePropertiesText => _visibleProperties.map((e) => e.name).join(',');

  static String _sortLabel(BookmarkSortField field) => switch (field) {
        BookmarkSortField.createdAt => '登録日時',
        BookmarkSortField.title => 'タイトル',
        BookmarkSortField.url => 'URL',
      };

  static String _propertyLabel(ViewProperty property) => switch (property) {
        ViewProperty.image => '画像',
        ViewProperty.url => 'URL',
        ViewProperty.tags => 'タグ',
        ViewProperty.people => '出演者',
        ViewProperty.description => '説明',
        ViewProperty.createdAt => '登録日時',
        ViewProperty.favorite => 'お気に入り',
        ViewProperty.status => 'ステータス',
        ViewProperty.rating => '評価',
        ViewProperty.history => '履歴',
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
      if (_statusFilter.isNotEmpty && bookmark.status != _statusFilter) return false;
      if (bookmark.rating < _minRating) return false;
      if (_personFilterId != null && !bookmark.people.any((person) => person.id == _personFilterId)) return false;
      if (_photoFilterId != null && !bookmark.photos.any((photo) => photo.id == _photoFilterId)) return false;
      if (query.isNotEmpty) {
        final text = [
          bookmark.title,
          bookmark.url,
          bookmark.description ?? '',
          _statusLabels[bookmark.status] ?? bookmark.status,
          ...bookmark.tags.map((tag) => tag.name),
          ...bookmark.people.map((person) => person.name),
          ...bookmark.collections.map((collection) => collection.name),
        ].join(' ').toLowerCase();
        if (!text.contains(query)) return false;
      }
      if (_selectedTagIds.isNotEmpty) {
        final bookmarkTagIds = bookmark.tags.map((tag) => tag.id).toSet();
        if (_tagMatchMode == TagMatchMode.or) {
          final allowed = <int>{};
          for (final id in _selectedTagIds) {
            allowed.add(id);
            if (_includeDescendants) allowed.addAll(_descendantIds(id, allTags));
          }
          if (!allowed.any(bookmarkTagIds.contains)) return false;
        } else {
          final matches = _selectedTagIds.every((id) {
            final allowed = <int>{id};
            if (_includeDescendants) allowed.addAll(_descendantIds(id, allTags));
            return allowed.any(bookmarkTagIds.contains);
          });
          if (!matches) return false;
        }
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

  void _selectBookmark(BookmarkItem bookmark) {
    if (_selectionMode) {
      _toggleBatchSelection(bookmark.id);
    } else {
      setState(() => _selectedBookmarkId = bookmark.id);
    }
  }

  void _toggleBatchSelection(int id) => setState(() {
        _batchSelectedIds.contains(id) ? _batchSelectedIds.remove(id) : _batchSelectedIds.add(id);
      });

  void _setSelectionMode(bool enabled) => setState(() {
        _selectionMode = enabled;
        if (!enabled) _batchSelectedIds.clear();
      });

  void _filterByTag(Tag tag) {
    _searchController.clear();
    setState(() {
      _query = '';
      _favoritesOnly = false;
      _personFilterId = null;
      _photoFilterId = null;
      _relationFilterLabel = 'タグ: ${tag.name}';
      _activeSavedViewId = null;
      _selectedTagIds
        ..clear()
        ..add(tag.id);
      _selectedBookmarkId = null;
    });
  }

  void _filterByPerson(Person person) {
    _searchController.clear();
    setState(() {
      _query = '';
      _favoritesOnly = false;
      _selectedTagIds.clear();
      _photoFilterId = null;
      _personFilterId = person.id;
      _relationFilterLabel = '出演者: ${person.name}';
      _activeSavedViewId = null;
      _selectedBookmarkId = null;
    });
  }

  void _filterByPhoto(PhotoRecord photo) {
    _searchController.clear();
    setState(() {
      _query = '';
      _favoritesOnly = false;
      _selectedTagIds.clear();
      _personFilterId = null;
      _photoFilterId = photo.id;
      _relationFilterLabel = '写真: ${photo.title?.trim().isNotEmpty == true ? photo.title! : '写真 ${photo.id}'}';
      _activeSavedViewId = null;
      _selectedBookmarkId = null;
    });
  }

  void _clearRelationFilter() => setState(() {
        _personFilterId = null;
        _photoFilterId = null;
        _relationFilterLabel = null;
      });

  Future<void> _openBookmark(BookmarkItem bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null) return;
    await widget.repository.recordOpen(bookmark);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
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
        tooltip: 'その他',
        padding: EdgeInsets.zero,
        iconSize: 18,
        onSelected: (value) {
          if (value == 'details') setState(() => _selectedBookmarkId = bookmark.id);
          if (value == 'select') {
            setState(() {
              _selectionMode = true;
              _batchSelectedIds.add(bookmark.id);
            });
          }
          if (value == 'open') _openBookmark(bookmark);
          if (value == 'delete') _deleteBookmark(bookmark);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'details', child: Text('詳細を表示')),
          PopupMenuItem(value: 'select', child: Text('選択する')),
          PopupMenuItem(value: 'open', child: Text('ブラウザで開く')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      );

  Widget _placeholder(double size) => Center(child: Icon(Icons.image_outlined, size: size, color: const Color(0xFF9B9A97)));

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
          final columns = constraints.maxWidth >= 1200
              ? 4
              : constraints.maxWidth >= 850
                  ? 3
                  : constraints.maxWidth >= 560
                      ? 2
                      : 1;
          return MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              final batchSelected = _batchSelectedIds.contains(bookmark.id);
              return Stack(
                children: [
                  NotionBookmarkCard(
                    bookmark: bookmark,
                    selected: _selectionMode ? batchSelected : bookmark.id == _selectedBookmarkId,
                    showImage: _visibleProperties.contains(ViewProperty.image),
                    showUrl: _visibleProperties.contains(ViewProperty.url),
                    showTags: _visibleProperties.contains(ViewProperty.tags),
                    showPeople: _visibleProperties.contains(ViewProperty.people),
                    showDescription: _visibleProperties.contains(ViewProperty.description),
                    showCreatedAt: _visibleProperties.contains(ViewProperty.createdAt),
                    showFavorite: _visibleProperties.contains(ViewProperty.favorite),
                    showStatus: _visibleProperties.contains(ViewProperty.status),
                    showRating: _visibleProperties.contains(ViewProperty.rating),
                    showHistory: _visibleProperties.contains(ViewProperty.history),
                    onTap: () => _selectBookmark(bookmark),
                    onToggleFavorite: () => widget.repository.toggleFavorite(bookmark),
                    menu: _bookmarkMenu(bookmark),
                  ),
                  if (_selectionMode)
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Material(
                        color: Colors.white.withValues(alpha: .94),
                        shape: const CircleBorder(),
                        child: Checkbox(
                          visualDensity: VisualDensity.compact,
                          value: batchSelected,
                          onChanged: (_) => _toggleBatchSelection(bookmark.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      );

  Widget _list(List<BookmarkItem> bookmarks) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
        itemCount: bookmarks.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 12, endIndent: 12),
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          return ListTile(
            minVerticalPadding: 10,
            selected: _selectionMode ? _batchSelectedIds.contains(bookmark.id) : bookmark.id == _selectedBookmarkId,
            selectedTileColor: const Color(0xFFF1F1EF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onTap: () => _selectBookmark(bookmark),
            leading: _selectionMode
                ? Checkbox(value: _batchSelectedIds.contains(bookmark.id), onChanged: (_) => _toggleBatchSelection(bookmark.id))
                : _visibleProperties.contains(ViewProperty.image)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(width: 60, height: 44, child: _image(bookmark, width: 60, height: 44, placeholderSize: 22)),
                      )
                    : null,
            title: Text(bookmark.title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF37352F))),
            subtitle: _listSubtitle(bookmark),
            trailing: _selectionMode
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_visibleProperties.contains(ViewProperty.favorite))
                        IconButton(
                          tooltip: 'お気に入り',
                          onPressed: () => widget.repository.toggleFavorite(bookmark),
                          icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border, size: 19),
                        ),
                      _bookmarkMenu(bookmark),
                    ],
                  ),
          );
        },
      );

  Widget? _listSubtitle(BookmarkItem bookmark) {
    final parts = <String>[
      if (_visibleProperties.contains(ViewProperty.url)) _compactUrl(bookmark.url),
      if (_visibleProperties.contains(ViewProperty.status)) _statusLabels[bookmark.status] ?? bookmark.status,
      if (_visibleProperties.contains(ViewProperty.rating) && bookmark.rating > 0) '★' * bookmark.rating,
      if (_visibleProperties.contains(ViewProperty.tags) && bookmark.tags.isNotEmpty) bookmark.tags.map((e) => e.name).join(', '),
      if (_visibleProperties.contains(ViewProperty.people) && bookmark.people.isNotEmpty) bookmark.people.map((e) => e.name).join(', '),
      if (_visibleProperties.contains(ViewProperty.description) && bookmark.description?.trim().isNotEmpty == true) bookmark.description!,
      if (_visibleProperties.contains(ViewProperty.createdAt)) _formatDate(bookmark.createdAt),
      if (_visibleProperties.contains(ViewProperty.history)) '${bookmark.openCount}回閲覧',
    ];
    if (parts.isEmpty) return null;
    return Text(parts.join('  ·  '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF787774), height: 1.4));
  }

  String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  Widget _table(List<BookmarkItem> bookmarks) {
    final properties = ViewProperty.values.where(_visibleProperties.contains).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: _selectionMode,
        headingRowHeight: 38,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 66,
        horizontalMargin: 12,
        columnSpacing: 24,
        headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF787774)),
        columns: [
          const DataColumn(label: Text('タイトル')),
          ...properties.map((property) => DataColumn(label: Text(_propertyLabel(property)))),
          const DataColumn(label: Text('')),
        ],
        rows: bookmarks.map((bookmark) {
          final cells = <DataCell>[DataCell(Text(bookmark.title, style: const TextStyle(fontWeight: FontWeight.w500)))];
          for (final property in properties) {
            cells.add(switch (property) {
              ViewProperty.image => DataCell(ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(width: 58, height: 38, child: _image(bookmark, width: 58, height: 38, placeholderSize: 20)),
                )),
              ViewProperty.url => DataCell(Text(_compactUrl(bookmark.url), style: const TextStyle(color: Color(0xFF787774)))),
              ViewProperty.tags => DataCell(Text(bookmark.tags.map((e) => e.name).join(', '))),
              ViewProperty.people => DataCell(Text(bookmark.people.map((e) => e.name).join(', '))),
              ViewProperty.description => DataCell(SizedBox(width: 280, child: Text(bookmark.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis))),
              ViewProperty.createdAt => DataCell(Text(_formatDate(bookmark.createdAt), style: const TextStyle(color: Color(0xFF9B9A97)))),
              ViewProperty.favorite => DataCell(IconButton(onPressed: () => widget.repository.toggleFavorite(bookmark), icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border, size: 18))),
              ViewProperty.status => DataCell(Text(_statusLabels[bookmark.status] ?? bookmark.status)),
              ViewProperty.rating => DataCell(Text(bookmark.rating == 0 ? '' : '★' * bookmark.rating)),
              ViewProperty.history => DataCell(Text('${bookmark.openCount}回')),
            });
          }
          cells.add(DataCell(_selectionMode ? const SizedBox.shrink() : _bookmarkMenu(bookmark)));
          return DataRow(
            selected: _selectionMode ? _batchSelectedIds.contains(bookmark.id) : bookmark.id == _selectedBookmarkId,
            onSelectChanged: (_) => _selectBookmark(bookmark),
            cells: cells,
          );
        }).toList(),
      ),
    );
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _activeSavedViewId = null;
      _query = '';
      _favoritesOnly = false;
      _statusFilter = '';
      _minRating = 0;
      _selectedTagIds.clear();
      _personFilterId = null;
      _photoFilterId = null;
      _relationFilterLabel = null;
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
      _statusFilter = view.statusFilter;
      _minRating = view.minRating;
      _viewType = _parseViewType(view.layoutType);
      _tagMatchMode = _parseMatchMode(view.tagMatchMode);
      _sortField = _parseSortField(view.sortField);
      _sortDirection = _parseSortDirection(view.sortDirection);
      _personFilterId = null;
      _photoFilterId = null;
      _relationFilterLabel = null;
      _selectedTagIds
        ..clear()
        ..addAll(config.tags.map((tag) => tag.id));
      _visibleProperties
        ..clear()
        ..addAll(_parseVisibleProperties(view.visibleProperties));
    });
  }

  Future<void> _saveCurrentView() async {
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ビューを保存'),
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
                visibleProperties: _visiblePropertiesText,
                statusFilter: _statusFilter,
                minRating: _minRating,
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

  Future<void> _showPropertiesDialog() async {
    final selected = {..._visibleProperties};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('プロパティ'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ViewProperty.values
                  .map((property) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_propertyLabel(property)),
                        value: selected.contains(property),
                        onChanged: (value) => setLocalState(() => value == true ? selected.add(property) : selected.remove(property)),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _activeSavedViewId = null;
                  _visibleProperties
                    ..clear()
                    ..addAll(selected);
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

  Future<void> _showFilterDialog(List<Tag> allTags) async {
    var favorites = _favoritesOnly;
    var matchMode = _tagMatchMode;
    var includeDescendants = _includeDescendants;
    var status = _statusFilter;
    var minRating = _minRating;
    final selectedTags = {..._selectedTagIds};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('フィルター'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('お気に入りのみ'), value: favorites, onChanged: (value) => setLocalState(() => favorites = value)),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'ステータス'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('すべて')),
                      ..._statusLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))),
                    ],
                    onChanged: (value) => setLocalState(() => status = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: minRating,
                    decoration: const InputDecoration(labelText: '最低評価'),
                    items: List.generate(6, (index) => DropdownMenuItem(value: index, child: Text(index == 0 ? '指定なし' : '${'★' * index} 以上'))),
                    onChanged: (value) => setLocalState(() => minRating = value ?? 0),
                  ),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('子タグも含める'), value: includeDescendants, onChanged: (value) => setLocalState(() => includeDescendants = value)),
                  Row(
                    children: [
                      const Text('タグ条件'),
                      const Spacer(),
                      SegmentedButton<TagMatchMode>(
                        segments: const [ButtonSegment(value: TagMatchMode.or, label: Text('OR')), ButtonSegment(value: TagMatchMode.and, label: Text('AND'))],
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
                          onSelected: (selected) => setLocalState(() => selected ? selectedTags.add(tag.id) : selectedTags.remove(tag.id)),
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
                  _statusFilter = status;
                  _minRating = minRating;
                  _tagMatchMode = matchMode;
                  _includeDescendants = includeDescendants;
                  _personFilterId = null;
                  _photoFilterId = null;
                  _relationFilterLabel = null;
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

  Future<void> _batchTags({required bool remove}) async {
    final tags = await widget.repository.watchTags().first;
    if (!mounted) return;
    final selected = await showTagDatabasePicker(context: context, tags: tags);
    if (selected == null || selected.isEmpty) return;
    if (remove) {
      await widget.repository.batchRemoveTags(_batchSelectedIds, selected.map((e) => e.name));
    } else {
      await widget.repository.batchAddTags(_batchSelectedIds, selected.map((e) => e.name));
    }
  }

  Future<void> _batchPeople({required bool remove}) async {
    final people = await widget.repository.watchPeople().first;
    if (!mounted) return;
    final selected = await showPeopleDatabasePicker(context: context, people: people);
    if (selected == null || selected.isEmpty) return;
    if (remove) {
      await widget.repository.batchRemovePeople(_batchSelectedIds, selected.map((e) => e.name));
    } else {
      await widget.repository.batchAddPeople(_batchSelectedIds, selected.map((e) => e.name));
    }
  }

  Future<void> _batchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_batchSelectedIds.length}件を削除しますか？'),
        content: const Text('この操作は元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.batchDelete(_batchSelectedIds);
      _setSelectionMode(false);
    }
  }

  Widget _batchBar(List<BookmarkItem> visible) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(color: Color(0xFFF7F7F5), border: Border(bottom: BorderSide(color: Color(0xFFE7E7E4)))),
        child: Row(
          children: [
            Checkbox(
              value: visible.isNotEmpty && visible.every((item) => _batchSelectedIds.contains(item.id)),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _batchSelectedIds.addAll(visible.map((e) => e.id));
                } else {
                  _batchSelectedIds.removeAll(visible.map((e) => e.id));
                }
              }),
            ),
            Text('${_batchSelectedIds.length}件選択', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'tag_add') _batchTags(remove: false);
                if (value == 'tag_remove') _batchTags(remove: true);
                if (value == 'people_add') _batchPeople(remove: false);
                if (value == 'people_remove') _batchPeople(remove: true);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'tag_add', child: Text('タグを追加')),
                PopupMenuItem(value: 'tag_remove', child: Text('タグを削除')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'people_add', child: Text('出演者を追加')),
                PopupMenuItem(value: 'people_remove', child: Text('出演者を削除')),
              ],
              child: const TextButton.icon(onPressed: null, icon: Icon(Icons.edit_outlined), label: Text('Relation編集')),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => widget.repository.batchSetStatus(_batchSelectedIds, value),
              itemBuilder: (_) => _statusLabels.entries.map((entry) => PopupMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              child: const TextButton.icon(onPressed: null, icon: Icon(Icons.flag_outlined), label: Text('ステータス')),
            ),
            PopupMenuButton<int>(
              onSelected: (value) => widget.repository.batchSetRating(_batchSelectedIds, value),
              itemBuilder: (_) => List.generate(6, (index) => PopupMenuItem(value: index, child: Text(index == 0 ? '評価を解除' : '${'★' * index}${'☆' * (5 - index)}'))),
              child: const TextButton.icon(onPressed: null, icon: Icon(Icons.star_outline), label: Text('評価')),
            ),
            TextButton.icon(onPressed: () => widget.repository.batchSetFavorite(_batchSelectedIds, true), icon: const Icon(Icons.star), label: const Text('お気に入り')),
            const Spacer(),
            IconButton(tooltip: '削除', onPressed: _batchSelectedIds.isEmpty ? null : _batchDelete, icon: const Icon(Icons.delete_outline)),
            IconButton(tooltip: '選択を終了', onPressed: () => _setSelectionMode(false), icon: const Icon(Icons.close)),
          ],
        ),
      );

  Widget _toolbar(List<Tag> allTags) {
    final filterCount = (_favoritesOnly ? 1 : 0) + (_statusFilter.isEmpty ? 0 : 1) + (_minRating > 0 ? 1 : 0) + _selectedTagIds.length + (_relationFilterLabel == null ? 0 : 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE7E7E4)))),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: '検索',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { _searchController.clear(); setState(() => _query = ''); }),
                filled: true,
                fillColor: const Color(0xFFF7F7F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (_relationFilterLabel != null) ...[
            InputChip(label: Text(_relationFilterLabel!, style: const TextStyle(fontSize: 12)), onDeleted: _clearRelationFilter, visualDensity: VisualDensity.compact),
            const SizedBox(width: 4),
          ],
          _toolbarButton(icon: Icons.filter_alt_outlined, label: filterCount == 0 ? 'フィルター' : 'フィルター $filterCount', onPressed: () => _showFilterDialog(allTags)),
          PopupMenuButton<BookmarkSortField>(
            tooltip: '並び替え',
            initialValue: _sortField,
            onSelected: (value) => setState(() => _sortField = value),
            itemBuilder: (_) => BookmarkSortField.values.map((field) => PopupMenuItem(value: field, child: Text(_sortLabel(field)))).toList(),
            child: _toolbarSurface(icon: Icons.swap_vert, label: _sortLabel(_sortField)),
          ),
          IconButton(
            tooltip: _sortDirection == SortDirection.asc ? '昇順' : '降順',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _sortDirection = _sortDirection == SortDirection.asc ? SortDirection.desc : SortDirection.asc),
            icon: Icon(_sortDirection == SortDirection.asc ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
          ),
          _toolbarButton(icon: Icons.tune, label: 'プロパティ', onPressed: _showPropertiesDialog),
          _toolbarButton(icon: Icons.check_box_outlined, label: '選択', onPressed: () => _setSelectionMode(!_selectionMode)),
          const Spacer(),
          SegmentedButton<BookmarkViewType>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: BookmarkViewType.gallery, icon: Icon(Icons.grid_view, size: 17)),
              ButtonSegment(value: BookmarkViewType.list, icon: Icon(Icons.view_list, size: 17)),
              ButtonSegment(value: BookmarkViewType.table, icon: Icon(Icons.table_rows, size: 17)),
            ],
            selected: {_viewType},
            onSelectionChanged: (value) => setState(() => _viewType = value.first),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'ビュー操作',
            icon: const Icon(Icons.more_horiz, size: 20),
            onSelected: (value) { if (value == 'save') _saveCurrentView(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'save', child: ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(Icons.bookmark_add_outlined, size: 18), title: Text('現在のビューを保存'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({required IconData icon, required String label, required VoidCallback onPressed}) => TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF565653), visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
      );

  Widget _toolbarSurface({required IconData icon, required String label}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: const Color(0xFF565653)), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF565653)))]),
      );

  Widget _tagTree(List<Tag> allTags, int? parentId, int depth) {
    final children = _childrenOf(parentId, allTags);
    return Column(
      children: children.map((tag) {
        final nested = _childrenOf(tag.id, allTags);
        final selected = _selectedTagIds.length == 1 && _selectedTagIds.contains(tag.id);
        return Column(
          children: [
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              selectedTileColor: const Color(0xFFEFEFED),
              contentPadding: EdgeInsets.only(left: 8 + depth * 16, right: 6),
              leading: Icon(nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined, size: 17, color: const Color(0xFF787774)),
              title: Text(tag.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              selected: selected,
              onTap: () => _filterByTag(tag),
            ),
            if (nested.isNotEmpty) _tagTree(allTags, tag.id, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _sidebar(List<Tag> allTags, List<SavedViewConfig> savedViews) {
    if (_sidebarCollapsed) {
      return Container(
        width: 42,
        color: const Color(0xFFF7F7F5),
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: IconButton(tooltip: 'サイドバーを開く', onPressed: () => setState(() => _sidebarCollapsed = false), icon: const Icon(Icons.chevron_right, size: 19)),
        ),
      );
    }
    return Container(
      width: 220,
      color: const Color(0xFFF7F7F5),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 20),
        children: [
          Align(alignment: Alignment.centerRight, child: IconButton(tooltip: 'サイドバーを閉じる', visualDensity: VisualDensity.compact, onPressed: () => setState(() => _sidebarCollapsed = true), icon: const Icon(Icons.chevron_left, size: 18))),
          _sidebarTile(icon: Icons.all_inbox_outlined, label: 'すべて', onTap: _resetFilters),
          _sidebarTile(
            icon: Icons.star_outline,
            label: 'お気に入り',
            selected: _favoritesOnly && _selectedTagIds.isEmpty,
            onTap: () {
              _searchController.clear();
              setState(() {
                _activeSavedViewId = null;
                _query = '';
                _favoritesOnly = true;
                _selectedTagIds.clear();
                _personFilterId = null;
                _photoFilterId = null;
                _relationFilterLabel = null;
              });
            },
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const Padding(padding: EdgeInsets.fromLTRB(9, 14, 8, 5), child: Text('保存ビュー', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF787774)))),
          ...savedViews.map((config) => ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                selectedTileColor: const Color(0xFFEFEFED),
                leading: const Icon(Icons.view_quilt_outlined, size: 17, color: Color(0xFF787774)),
                title: Text(config.view.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                selected: _activeSavedViewId == config.view.id,
                onTap: () => _applySavedView(config),
                trailing: IconButton(tooltip: '削除', visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 14), onPressed: () => widget.repository.deleteSavedView(config.view.id)),
              )),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 12, 0, 4),
            child: Row(
              children: [
                const Expanded(child: Text('タグ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF787774)))),
                Transform.scale(scale: .78, child: Switch(value: _includeDescendants, onChanged: (v) => setState(() => _includeDescendants = v))),
              ],
            ),
          ),
          _tagTree(allTags, null, 0),
        ],
      ),
    );
  }

  Widget _sidebarTile({required IconData icon, required String label, required VoidCallback onTap, bool selected = false}) => ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        selectedTileColor: const Color(0xFFEFEFED),
        leading: Icon(icon, size: 18, color: const Color(0xFF565653)),
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
        selected: selected,
        onTap: onTap,
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
              backgroundColor: Colors.white,
              appBar: AppBar(
                toolbarHeight: 50,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bookmarks_outlined, size: 20), SizedBox(width: 7), Text('Bookmarks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))]),
              ),
              floatingActionButton: _selectionMode ? null : FloatingActionButton.extended(
                onPressed: () => showBookmarkCreateDialog(context: context, repository: widget.repository),
                icon: const Icon(Icons.add, size: 18),
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
                      const VerticalDivider(width: 1, color: Color(0xFFE7E7E4)),
                      Expanded(
                        child: Column(
                          children: [
                            _toolbar(allTags),
                            if (_selectionMode) _batchBar(bookmarks),
                            Expanded(
                              child: bookmarks.isEmpty
                                  ? const Center(child: Text('条件に一致するブックマークがありません', style: TextStyle(color: Color(0xFF9B9A97))))
                                  : switch (_viewType) {
                                      BookmarkViewType.gallery => _gallery(bookmarks),
                                      BookmarkViewType.list => _list(bookmarks),
                                      BookmarkViewType.table => _table(bookmarks),
                                    },
                            ),
                          ],
                        ),
                      ),
                      if (selected != null && !_selectionMode) ...[
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) => setState(() {
                              _detailWidth = (_detailWidth - details.delta.dx).clamp(320.0, 720.0);
                            }),
                            child: Container(width: 6, color: const Color(0xFFE7E7E4).withValues(alpha: .45)),
                          ),
                        ),
                        SizedBox(
                          width: _detailWidth,
                          child: BookmarkDetailPanel(
                            key: ValueKey(selected.id),
                            repository: widget.repository,
                            bookmark: selected,
                            onClose: () => setState(() => _selectedBookmarkId = null),
                            onFilterByTag: _filterByTag,
                            onFilterByPerson: _filterByPerson,
                            onFilterByPhoto: _filterByPhoto,
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
