import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../widgets/bookmark_create_dialog.dart';
import '../widgets/bookmark_detail_panel.dart';
import '../widgets/notion_bookmark_card.dart';

enum BookmarkStage1ViewType { gallery, list, table }
enum BookmarkStage1SortField { createdAt, title, url }
enum BookmarkStage1Property {
  image,
  url,
  tags,
  people,
  description,
  createdAt,
  favorite,
  status,
  rating,
  history,
}

const _statusLabels = <String, String>{
  'unread': '未読',
  'later': '後で見る',
  'in_progress': '閲覧中 / 視聴中',
  'done': '完了 / 視聴済み',
  'archived': 'アーカイブ',
};

class BookmarkUnifiedStage1Page extends StatefulWidget {
  const BookmarkUnifiedStage1Page({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<BookmarkUnifiedStage1Page> createState() => _BookmarkUnifiedStage1PageState();
}

class _BookmarkUnifiedStage1PageState extends State<BookmarkUnifiedStage1Page> {
  final _searchController = TextEditingController();
  final Set<int> _selectedTagIds = {};
  final Set<BookmarkStage1Property> _visibleProperties = {
    BookmarkStage1Property.image,
    BookmarkStage1Property.url,
    BookmarkStage1Property.tags,
    BookmarkStage1Property.favorite,
  };

  BookmarkStage1ViewType _viewType = BookmarkStage1ViewType.gallery;
  BookmarkStage1SortField _sortField = BookmarkStage1SortField.createdAt;
  bool _sortAscending = false;
  bool _favoritesOnly = false;
  bool _includeDescendants = true;
  bool _sidebarCollapsed = false;
  String _statusFilter = '';
  int _minRating = 0;
  String _query = '';
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

  List<Tag> _childrenOf(int? parentId, List<Tag> tags) {
    final result = tags.where((tag) => tag.parentTagId == parentId).toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

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
    final q = _query.trim().toLowerCase();
    final result = source.where((bookmark) {
      if (_favoritesOnly && !bookmark.favorite) return false;
      if (_statusFilter.isNotEmpty && bookmark.status != _statusFilter) return false;
      if (bookmark.rating < _minRating) return false;
      if (_personFilterId != null && !bookmark.people.any((person) => person.id == _personFilterId)) return false;
      if (_photoFilterId != null && !bookmark.photos.any((photo) => photo.id == _photoFilterId)) return false;

      if (q.isNotEmpty) {
        final searchable = [
          bookmark.title,
          bookmark.url,
          bookmark.description ?? '',
          _statusLabels[bookmark.status] ?? bookmark.status,
          ...bookmark.tags.map((tag) => tag.name),
          ...bookmark.people.map((person) => person.name),
        ].join(' ').toLowerCase();
        if (!searchable.contains(q)) return false;
      }

      if (_selectedTagIds.isNotEmpty) {
        final bookmarkTagIds = bookmark.tags.map((tag) => tag.id).toSet();
        final allowed = <int>{};
        for (final id in _selectedTagIds) {
          allowed.add(id);
          if (_includeDescendants) allowed.addAll(_descendantIds(id, allTags));
        }
        if (!allowed.any(bookmarkTagIds.contains)) return false;
      }
      return true;
    }).toList();

    int compare(BookmarkItem a, BookmarkItem b) {
      final value = switch (_sortField) {
        BookmarkStage1SortField.createdAt => a.createdAt.compareTo(b.createdAt),
        BookmarkStage1SortField.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        BookmarkStage1SortField.url => a.url.toLowerCase().compareTo(b.url.toLowerCase()),
      };
      return _sortAscending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _favoritesOnly = false;
      _statusFilter = '';
      _minRating = 0;
      _selectedTagIds.clear();
      _personFilterId = null;
      _photoFilterId = null;
      _relationFilterLabel = null;
    });
  }

  void _filterByTag(Tag tag) {
    _searchController.clear();
    setState(() {
      _query = '';
      _favoritesOnly = false;
      _personFilterId = null;
      _photoFilterId = null;
      _relationFilterLabel = 'タグ: ${tag.name}';
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
      _selectedBookmarkId = null;
    });
  }

  Future<void> _openBookmark(BookmarkItem bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null) return;
    await widget.repository.recordOpen(bookmark);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
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
      if (_selectedBookmarkId == bookmark.id && mounted) {
        setState(() => _selectedBookmarkId = null);
      }
    }
  }

  Widget _bookmarkMenu(BookmarkItem bookmark) => PopupMenuButton<String>(
        tooltip: 'その他',
        iconSize: 18,
        onSelected: (value) {
          if (value == 'detail') setState(() => _selectedBookmarkId = bookmark.id);
          if (value == 'open') _openBookmark(bookmark);
          if (value == 'delete') _deleteBookmark(bookmark);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'detail', child: Text('詳細を表示')),
          PopupMenuItem(value: 'open', child: Text('ブラウザで開く')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      );

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
              return NotionBookmarkCard(
                bookmark: bookmark,
                selected: bookmark.id == _selectedBookmarkId,
                showImage: _visibleProperties.contains(BookmarkStage1Property.image),
                showUrl: _visibleProperties.contains(BookmarkStage1Property.url),
                showTags: _visibleProperties.contains(BookmarkStage1Property.tags),
                showPeople: _visibleProperties.contains(BookmarkStage1Property.people),
                showDescription: _visibleProperties.contains(BookmarkStage1Property.description),
                showCreatedAt: _visibleProperties.contains(BookmarkStage1Property.createdAt),
                showFavorite: _visibleProperties.contains(BookmarkStage1Property.favorite),
                showStatus: _visibleProperties.contains(BookmarkStage1Property.status),
                showRating: _visibleProperties.contains(BookmarkStage1Property.rating),
                showHistory: _visibleProperties.contains(BookmarkStage1Property.history),
                onTap: () => setState(() => _selectedBookmarkId = bookmark.id),
                onToggleFavorite: () => widget.repository.toggleFavorite(bookmark),
                menu: _bookmarkMenu(bookmark),
              );
            },
          );
        },
      );

  Widget _image(BookmarkItem bookmark, {double width = 60, double height = 44}) {
    if (bookmark.coverPhoto != null) {
      return Image.file(
        File(bookmark.coverPhoto!.path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _networkImage(bookmark, width, height),
      );
    }
    return _networkImage(bookmark, width, height);
  }

  Widget _networkImage(BookmarkItem bookmark, double width, double height) {
    if (bookmark.thumbnail?.trim().isNotEmpty == true) {
      return Image.network(
        bookmark.thumbnail!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined)),
      );
    }
    return const Center(child: Icon(Icons.image_outlined));
  }

  Widget _list(List<BookmarkItem> bookmarks) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
        itemCount: bookmarks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          final details = <String>[
            if (_visibleProperties.contains(BookmarkStage1Property.url)) _compactUrl(bookmark.url),
            if (_visibleProperties.contains(BookmarkStage1Property.status)) _statusLabels[bookmark.status] ?? bookmark.status,
            if (_visibleProperties.contains(BookmarkStage1Property.rating) && bookmark.rating > 0) '★' * bookmark.rating,
            if (_visibleProperties.contains(BookmarkStage1Property.tags) && bookmark.tags.isNotEmpty)
              bookmark.tags.map((tag) => tag.name).join(', '),
            if (_visibleProperties.contains(BookmarkStage1Property.people) && bookmark.people.isNotEmpty)
              bookmark.people.map((person) => person.name).join(', '),
            if (_visibleProperties.contains(BookmarkStage1Property.description) && bookmark.description?.trim().isNotEmpty == true)
              bookmark.description!,
            if (_visibleProperties.contains(BookmarkStage1Property.createdAt)) _formatDate(bookmark.createdAt),
            if (_visibleProperties.contains(BookmarkStage1Property.history)) _historyText(bookmark),
          ];
          return ListTile(
            selected: bookmark.id == _selectedBookmarkId,
            selectedTileColor: const Color(0xFFF1F1EF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onTap: () => setState(() => _selectedBookmarkId = bookmark.id),
            leading: _visibleProperties.contains(BookmarkStage1Property.image)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(width: 60, height: 44, child: _image(bookmark)),
                  )
                : null,
            title: Text(bookmark.title),
            subtitle: details.isEmpty
                ? null
                : Text(details.join('  ·  '), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_visibleProperties.contains(BookmarkStage1Property.favorite))
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

  Widget _table(List<BookmarkItem> bookmarks) {
    final properties = BookmarkStage1Property.values.where(_visibleProperties.contains).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('タイトル')),
          ...properties.map((property) => DataColumn(label: Text(_propertyLabel(property)))),
          const DataColumn(label: Text('')),
        ],
        rows: bookmarks.map((bookmark) {
          final cells = <DataCell>[DataCell(Text(bookmark.title))];
          for (final property in properties) {
            cells.add(switch (property) {
              BookmarkStage1Property.image => DataCell(
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(width: 58, height: 38, child: _image(bookmark, width: 58, height: 38)),
                  ),
                ),
              BookmarkStage1Property.url => DataCell(Text(_compactUrl(bookmark.url))),
              BookmarkStage1Property.tags => DataCell(Text(bookmark.tags.map((tag) => tag.name).join(', '))),
              BookmarkStage1Property.people => DataCell(Text(bookmark.people.map((person) => person.name).join(', '))),
              BookmarkStage1Property.description => DataCell(
                  SizedBox(width: 260, child: Text(bookmark.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)),
                ),
              BookmarkStage1Property.createdAt => DataCell(Text(_formatDate(bookmark.createdAt))),
              BookmarkStage1Property.favorite => DataCell(
                  IconButton(
                    onPressed: () => widget.repository.toggleFavorite(bookmark),
                    icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border, size: 18),
                  ),
                ),
              BookmarkStage1Property.status => DataCell(Text(_statusLabels[bookmark.status] ?? bookmark.status)),
              BookmarkStage1Property.rating => DataCell(Text(bookmark.rating == 0 ? '' : '★' * bookmark.rating)),
              BookmarkStage1Property.history => DataCell(Text(_historyText(bookmark))),
            });
          }
          cells.add(DataCell(_bookmarkMenu(bookmark)));
          return DataRow(
            selected: bookmark.id == _selectedBookmarkId,
            onSelectChanged: (_) => setState(() => _selectedBookmarkId = bookmark.id),
            cells: cells,
          );
        }).toList(),
      ),
    );
  }

  String _propertyLabel(BookmarkStage1Property property) => switch (property) {
        BookmarkStage1Property.image => '画像',
        BookmarkStage1Property.url => 'URL',
        BookmarkStage1Property.tags => 'タグ',
        BookmarkStage1Property.people => '出演者',
        BookmarkStage1Property.description => '説明',
        BookmarkStage1Property.createdAt => '登録日時',
        BookmarkStage1Property.favorite => 'お気に入り',
        BookmarkStage1Property.status => 'ステータス',
        BookmarkStage1Property.rating => '評価',
        BookmarkStage1Property.history => '履歴',
      };

  String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}/$month/$day';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}/$month/$day $hour:$minute';
  }

  String _historyText(BookmarkItem bookmark) {
    if (bookmark.lastOpenedAt == null) return '${bookmark.openCount}回 · 未閲覧';
    return '${bookmark.openCount}回 · ${_formatDateTime(bookmark.lastOpenedAt!)}';
  }

  Future<void> _showPropertiesDialog() async {
    final selected = {..._visibleProperties};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('表示するプロパティ'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: BookmarkStage1Property.values.map((property) {
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_propertyLabel(property)),
                    value: selected.contains(property),
                    onChanged: (value) => setLocalState(() {
                      if (value == true) {
                        selected.add(property);
                      } else {
                        selected.remove(property);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                setState(() {
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

  Future<void> _showFilterDialog() async {
    var favorites = _favoritesOnly;
    var status = _statusFilter;
    var minRating = _minRating;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('フィルター'),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('お気に入りのみ'),
                  value: favorites,
                  onChanged: (value) => setLocalState(() => favorites = value),
                ),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'ステータス'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('すべて')),
                    ..._statusLabels.entries.map(
                      (entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                    ),
                  ],
                  onChanged: (value) => setLocalState(() => status = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: minRating,
                  decoration: const InputDecoration(labelText: '最低評価'),
                  items: List.generate(
                    6,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(index == 0 ? '指定なし' : '${'★' * index} 以上'),
                    ),
                  ),
                  onChanged: (value) => setLocalState(() => minRating = value ?? 0),
                ),
              ],
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

  Widget _toolbar() {
    final filterCount = (_favoritesOnly ? 1 : 0) + (_statusFilter.isNotEmpty ? 1 : 0) + (_minRating > 0 ? 1 : 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE7E7E4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 250,
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: '検索',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF7F7F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_relationFilterLabel != null) ...[
            InputChip(
              label: Text(_relationFilterLabel!, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() {
                _personFilterId = null;
                _photoFilterId = null;
                _relationFilterLabel = null;
              }),
            ),
            const SizedBox(width: 6),
          ],
          TextButton.icon(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_alt_outlined, size: 17),
            label: Text(filterCount == 0 ? 'フィルター' : 'フィルター $filterCount'),
          ),
          PopupMenuButton<BookmarkStage1SortField>(
            tooltip: '並び替え',
            initialValue: _sortField,
            onSelected: (value) => setState(() => _sortField = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: BookmarkStage1SortField.createdAt, child: Text('登録日時')),
              PopupMenuItem(value: BookmarkStage1SortField.title, child: Text('タイトル')),
              PopupMenuItem(value: BookmarkStage1SortField.url, child: Text('URL')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.swap_vert, size: 17), SizedBox(width: 5), Text('並び替え')]),
            ),
          ),
          IconButton(
            tooltip: _sortAscending ? '昇順' : '降順',
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
          ),
          TextButton.icon(
            onPressed: _showPropertiesDialog,
            icon: const Icon(Icons.tune, size: 17),
            label: const Text('プロパティ'),
          ),
          const Spacer(),
          SegmentedButton<BookmarkStage1ViewType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: BookmarkStage1ViewType.gallery, icon: Icon(Icons.grid_view, size: 17)),
              ButtonSegment(value: BookmarkStage1ViewType.list, icon: Icon(Icons.view_list, size: 17)),
              ButtonSegment(value: BookmarkStage1ViewType.table, icon: Icon(Icons.table_rows, size: 17)),
            ],
            selected: {_viewType},
            onSelectionChanged: (value) => setState(() => _viewType = value.first),
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
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.only(left: 8 + depth * 16, right: 6),
              leading: Icon(nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined, size: 17),
              title: Text(tag.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              selected: _selectedTagIds.length == 1 && _selectedTagIds.contains(tag.id),
              onTap: () => _filterByTag(tag),
            ),
            if (nested.isNotEmpty) _tagTree(allTags, tag.id, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _sidebar(List<Tag> allTags) {
    if (_sidebarCollapsed) {
      return Container(
        width: 42,
        color: const Color(0xFFF7F7F5),
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: IconButton(
            tooltip: 'サイドバーを開く',
            onPressed: () => setState(() => _sidebarCollapsed = false),
            icon: const Icon(Icons.chevron_right, size: 19),
          ),
        ),
      );
    }

    return Container(
      width: 220,
      color: const Color(0xFFF7F7F5),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 20),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'サイドバーを閉じる',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _sidebarCollapsed = true),
              icon: const Icon(Icons.chevron_left, size: 18),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.all_inbox_outlined, size: 18),
            title: const Text('すべて'),
            onTap: _resetFilters,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.star_outline, size: 18),
            title: const Text('お気に入り'),
            selected: _favoritesOnly,
            onTap: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _favoritesOnly = true;
                _selectedTagIds.clear();
                _personFilterId = null;
                _photoFilterId = null;
                _relationFilterLabel = null;
              });
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 0, 4),
            child: Row(
              children: [
                const Expanded(child: Text('タグ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                Transform.scale(
                  scale: .78,
                  child: Switch(
                    value: _includeDescendants,
                    onChanged: (value) => setState(() => _includeDescendants = value),
                  ),
                ),
              ],
            ),
          ),
          _tagTree(allTags, null, 0),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tag>>(
      stream: widget.repository.watchTags(),
      builder: (context, tagSnapshot) {
        final tags = tagSnapshot.data ?? const <Tag>[];
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            toolbarHeight: 50,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmarks_outlined, size: 20),
                SizedBox(width: 7),
                Text('Bookmarks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showBookmarkCreateDialog(context: context, repository: widget.repository),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('追加'),
          ),
          body: StreamBuilder<List<BookmarkItem>>(
            stream: widget.repository.watchAll(),
            builder: (context, bookmarkSnapshot) {
              if (!bookmarkSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final allBookmarks = bookmarkSnapshot.data!;
              final bookmarks = _applyFilters(allBookmarks, tags);
              final selected = allBookmarks.where((bookmark) => bookmark.id == _selectedBookmarkId).firstOrNull;

              return Row(
                children: [
                  _sidebar(tags),
                  const VerticalDivider(width: 1, color: Color(0xFFE7E7E4)),
                  Expanded(
                    child: Column(
                      children: [
                        _toolbar(),
                        Expanded(
                          child: bookmarks.isEmpty
                              ? const Center(child: Text('条件に一致するブックマークがありません'))
                              : switch (_viewType) {
                                  BookmarkStage1ViewType.gallery => _gallery(bookmarks),
                                  BookmarkStage1ViewType.list => _list(bookmarks),
                                  BookmarkStage1ViewType.table => _table(bookmarks),
                                },
                        ),
                      ],
                    ),
                  ),
                  if (selected != null) ...[
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _detailWidth = (_detailWidth - details.delta.dx).clamp(320.0, 720.0);
                          });
                        },
                        child: Container(width: 6, color: const Color(0xFFE7E7E4)),
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
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
