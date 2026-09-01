import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/database_view_store.dart';
import '../database/database_definition.dart';
import '../data/person_roles.dart';
import '../data/saved_view_extensions.dart';
import '../data/workspace_store.dart';
import '../services/bookmark_metadata_service.dart';
import '../services/photo_storage_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/bookmark_create_dialog.dart';
import '../widgets/bookmark_detail_panel.dart';
import '../widgets/bookmark_list_metadata.dart';
import '../widgets/database_create_tiles.dart';
import '../widgets/database_view_tabs.dart';
import '../widgets/bookmark_property_order_dialog.dart';
import '../widgets/notion_bookmark_card.dart';
import '../widgets/relation_database_picker.dart';
import 'bookmark_property_order.dart';
import 'bookmark_query_engine.dart';

class BookmarkUnifiedStage1Page extends StatefulWidget {
  const BookmarkUnifiedStage1Page({
    super.key,
    required this.repository,
    this.profileName = 'Default',
    this.workspaceName = 'Workspace',
  });

  final BookmarkRepository repository;
  final String profileName;
  final String workspaceName;

  @override
  State<BookmarkUnifiedStage1Page> createState() => _BookmarkUnifiedStage1PageState();
}

class _BookmarkUnifiedStage1PageState extends State<BookmarkUnifiedStage1Page> {
  final _searchController = TextEditingController();
  final Set<int> _selectedTagIds = {};
  final Set<int> _batchSelectedIds = {};
  final Set<BookmarkStage1Property> _visibleProperties = {
    BookmarkStage1Property.image,
    BookmarkStage1Property.url,
    BookmarkStage1Property.tags,
    BookmarkStage1Property.favorite,
  };
  final Set<String> _visiblePersonRoles = {};
  List<String> _propertyOrder = defaultBookmarkPropertyOrder();

  BookmarkStage1ViewType _viewType = BookmarkStage1ViewType.gallery;
  BookmarkStage1SortField _sortField = BookmarkStage1SortField.createdAt;
  bool _sortAscending = false;
  bool _favoritesOnly = false;
  bool _includeDescendants = true;
  bool _sidebarCollapsed = false;
  bool _selectionMode = false;
  bool _externalDragging = false;
  String _statusFilter = '';
  String _tagMatchMode = 'or';
  int _minRating = 0;
  String _query = '';
  int? _selectedBookmarkId;
  int? _personFilterId;
  int? _photoFilterId;
  int? _activeSavedViewId;
  String? _relationFilterLabel;
  double _detailWidth = 430;
  Timer? _savedViewSaveTimer;
  Timer? _databaseViewSaveTimer;
  late final DatabaseViewStore _databaseViewStore;
  int? _activeDatabaseViewId;
  DatabaseViewConfig? _activeDatabaseView;

  List<BookmarkStage1Property> get _orderedVisibleProperties =>
      orderedVisibleBookmarkProperties(_propertyOrder, _visibleProperties);

  List<String> get _orderedVisibleRoles =>
      orderedVisiblePersonRoles(_propertyOrder, _visiblePersonRoles);

  List<String> get _visiblePropertyTokens => visibleBookmarkPropertyTokens(
        _propertyOrder,
        _visibleProperties,
        _visiblePersonRoles,
      );

  @override
  void initState() {
    super.initState();
    _databaseViewStore = DatabaseViewStore(widget.repository.workspaceStore.database);
  }

  @override
  void dispose() {
    _savedViewSaveTimer?.cancel();
    _databaseViewSaveTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Tag> _childrenOf(int? parentId, List<Tag> tags) {
    final result = tags.where((tag) => tag.parentTagId == parentId).toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  List<BookmarkItem> _applyFilters(
    List<BookmarkItem> source,
    List<Tag> allTags,
  ) =>
      BookmarkQuery(
        query: _query,
        favoritesOnly: _favoritesOnly,
        statusFilter: _statusFilter,
        minRating: _minRating,
        personFilterId: _personFilterId,
        photoFilterId: _photoFilterId,
        selectedTagIds: _selectedTagIds,
        includeDescendants: _includeDescendants,
        tagMatchMode: _tagMatchMode,
        sortField: _sortField,
        sortAscending: _sortAscending,
      ).apply(source, allTags);

  void _applyDatabaseView(DatabaseViewConfig view) {
    final filters = view.filters;
    final sort = view.sorts.whereType<Map>().firstOrNull;
    final tokens = view.visibleProperties.isEmpty
        ? BuiltInDatabases.bookmarks.defaultVisibleProperties
        : view.visibleProperties;
    final base = <BookmarkStage1Property>{};
    final roles = <String>{};
    for (final key in tokens) {
      if (key.startsWith('role:')) {
        roles.add(key.substring(5));
      } else {
        final property = bookmarkPropertyFromKey(key);
        if (property != null) base.add(property);
      }
    }
    final query = (filters['query'] as String?) ?? '';
    final rawTagIds = filters['tagIds'];
    final tagIds = rawTagIds is List
        ? rawTagIds.whereType<num>().map((value) => value.toInt()).toSet()
        : <int>{};
    final width = view.settings['detailWidth'];
    _searchController.text = query;
    setState(() {
      _query = query;
      _favoritesOnly = filters['favoritesOnly'] == true;
      _statusFilter = (filters['status'] as String?) ?? '';
      _minRating = (filters['minRating'] as num?)?.toInt() ?? 0;
      _tagMatchMode = (filters['tagMatchMode'] as String?) ?? 'or';
      _includeDescendants = filters['includeDescendants'] != false;
      _personFilterId = (filters['personId'] as num?)?.toInt();
      _photoFilterId = (filters['photoId'] as num?)?.toInt();
      _selectedTagIds
        ..clear()
        ..addAll(tagIds);
      _viewType = switch (view.layoutType) {
        'list' => BookmarkStage1ViewType.list,
        'table' => BookmarkStage1ViewType.table,
        _ => BookmarkStage1ViewType.gallery,
      };
      final sortField = sort?['field'] as String?;
      _sortField = switch (sortField) {
        'title' => BookmarkStage1SortField.title,
        'url' => BookmarkStage1SortField.url,
        _ => BookmarkStage1SortField.createdAt,
      };
      _sortAscending = sort?['direction'] == 'asc';
      _propertyOrder = normalizeBookmarkPropertyOrder(
        view.propertyOrder.isEmpty ? tokens : view.propertyOrder,
      );
      _visibleProperties
        ..clear()
        ..addAll(base);
      _visiblePersonRoles
        ..clear()
        ..addAll(roles);
      if (width is num) {
        _detailWidth = width.toDouble().clamp(320.0, 720.0).toDouble();
      }
      _activeDatabaseViewId = view.id;
      _activeDatabaseView = view;
      _activeSavedViewId = null;
      _relationFilterLabel = null;
    });
  }

  void _scheduleDatabaseViewSave() {
    final active = _activeDatabaseView;
    if (active == null) return;
    _databaseViewSaveTimer?.cancel();
    _databaseViewSaveTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted && _activeDatabaseViewId == active.id) {
        _saveActiveDatabaseView();
      }
    });
  }

  Future<void> _saveActiveDatabaseView() async {
    final active = _activeDatabaseView;
    if (active == null) return;
    final next = active.copyWith(
      layoutType: _layoutKey,
      filters: {
        'query': _query,
        'favoritesOnly': _favoritesOnly,
        'tagIds': _selectedTagIds.toList(),
        'tagMatchMode': _tagMatchMode,
        'includeDescendants': _includeDescendants,
        'status': _statusFilter,
        'minRating': _minRating,
        'personId': _personFilterId,
        'photoId': _photoFilterId,
      },
      sorts: [
        {'field': _sortKey, 'direction': _sortAscending ? 'asc' : 'desc'},
      ],
      visibleProperties: _visiblePropertyTokens,
      propertyOrder: _propertyOrder,
      settings: {...active.settings, 'detailWidth': _detailWidth},
    );
    await _databaseViewStore.updateView(next);
    if (mounted && _activeDatabaseViewId == active.id) {
      _activeDatabaseView = next;
    }
  }

  Widget _databaseViewTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 10, 0),
        child: DatabaseViewTabs(
          store: _databaseViewStore,
          definition: BuiltInDatabases.bookmarks,
          workspaceId: widget.repository.workspaceId,
          activeViewId: _activeDatabaseViewId,
          onSelected: _applyDatabaseView,
        ),
      );

  void _markViewChanged() {
    _scheduleDatabaseViewSave();
    final id = _activeSavedViewId;
    if (id == null) return;
    _savedViewSaveTimer?.cancel();
    _savedViewSaveTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted && _activeSavedViewId == id) _updateActiveView();
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _favoritesOnly = false;
      _statusFilter = '';
      _minRating = 0;
      _selectedTagIds.clear();
      _tagMatchMode = 'or';
      _includeDescendants = true;
      _personFilterId = null;
      _photoFilterId = null;
      _relationFilterLabel = null;
      _markViewChanged();
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
      _markViewChanged();
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
      _relationFilterLabel = '人物: ${person.name}';
      _selectedBookmarkId = null;
      _markViewChanged();
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
      _markViewChanged();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedBookmarkId = null;
      if (!_selectionMode) _batchSelectedIds.clear();
    });
  }

  void _selectBookmark(BookmarkItem bookmark) {
    if (_selectionMode) {
      setState(() {
        _batchSelectedIds.contains(bookmark.id)
            ? _batchSelectedIds.remove(bookmark.id)
            : _batchSelectedIds.add(bookmark.id);
      });
    } else {
      setState(() => _selectedBookmarkId = bookmark.id);
    }
  }

  Future<void> _openBookmark(BookmarkItem bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null) return;
    await widget.repository.recordOpen(bookmark);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URLを開けませんでした')),
      );
    }
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
    if (confirmed == true) {
      await widget.repository.delete(bookmark.id);
      if (!mounted) return;
      if (_selectedBookmarkId == bookmark.id) {
        setState(() => _selectedBookmarkId = null);
      }
      showAppToast(
        context,
        'ブックマークをゴミ箱へ移動しました',
        actionLabel: '元に戻す',
        onAction: () => widget.repository.restoreFromTrash(bookmark),
      );
    }
  }

  Future<WorkspaceInfo?> _chooseWorkspace({int? excludingId}) async {
    final workspaces = await widget.repository.listWorkspaces();
    if (!mounted) return null;
    return showDialog<WorkspaceInfo>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Workspaceへ移動'),
        children: workspaces
            .where((workspace) => workspace.id != excludingId)
            .map(
              (workspace) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, workspace),
                child: Row(children: [
                  Text(workspace.icon),
                  const SizedBox(width: 9),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Color(workspace.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(workspace.name)),
                ]),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _moveBookmark(BookmarkItem bookmark) async {
    final workspace = await _chooseWorkspace(
      excludingId: widget.repository.workspaceId,
    );
    if (workspace == null) return;
    await widget.repository.moveBookmarksToWorkspace([bookmark.id], workspace);
    if (mounted) setState(() => _selectedBookmarkId = null);
  }

  Future<void> _moveBatch() async {
    if (_batchSelectedIds.isEmpty) return;
    final workspace = await _chooseWorkspace(
      excludingId: widget.repository.workspaceId,
    );
    if (workspace == null) return;
    await widget.repository.moveBookmarksToWorkspace(
      _batchSelectedIds,
      workspace,
    );
    if (!mounted) return;
    setState(() {
      _batchSelectedIds.clear();
      _selectionMode = false;
    });
  }

  Widget _bookmarkMenu(BookmarkItem bookmark) => PopupMenuButton<String>(
        tooltip: 'その他',
        iconSize: 18,
        onSelected: (value) {
          if (value == 'detail') {
            setState(() => _selectedBookmarkId = bookmark.id);
          }
          if (value == 'open') _openBookmark(bookmark);
          if (value == 'move') _moveBookmark(bookmark);
          if (value == 'select') {
            setState(() {
              _selectionMode = true;
              _selectedBookmarkId = null;
              _batchSelectedIds.add(bookmark.id);
            });
          }
          if (value == 'delete') _deleteBookmark(bookmark);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'detail', child: Text('詳細を表示')),
          PopupMenuItem(value: 'open', child: Text('ブラウザで開く')),
          PopupMenuItem(value: 'move', child: Text('Workspaceへ移動')),
          PopupMenuItem(value: 'select', child: Text('選択する')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      );

  Map<String, List<Person>> _roleGroups(
    List<PersonRoleAssignment> assignments,
  ) {
    final result = <String, List<Person>>{};
    for (final role in _orderedVisibleRoles) {
      final people = assignments
          .where((assignment) => assignment.role == role)
          .map((assignment) => assignment.person)
          .toList();
      if (people.isNotEmpty) result[role] = people;
    }
    return result;
  }

  Widget _roleAwareCard(BookmarkItem bookmark, {required bool selected}) {
    return StreamBuilder<List<PersonRoleAssignment>>(
      stream: widget.repository.watchPersonRoles(bookmark),
      builder: (context, snapshot) {
        final scheme = Theme.of(context).colorScheme;
        final card = NotionBookmarkCard(
          bookmark: bookmark,
          selected: selected,
          showImage: _visibleProperties.contains(BookmarkStage1Property.image),
          showUrl: _visibleProperties.contains(BookmarkStage1Property.url),
          showTags: _visibleProperties.contains(BookmarkStage1Property.tags),
          showPeople: _visibleProperties.contains(BookmarkStage1Property.people),
          showDescription:
              _visibleProperties.contains(BookmarkStage1Property.description),
          showCreatedAt:
              _visibleProperties.contains(BookmarkStage1Property.createdAt),
          showFavorite:
              _visibleProperties.contains(BookmarkStage1Property.favorite),
          showStatus:
              _visibleProperties.contains(BookmarkStage1Property.status),
          showRating:
              _visibleProperties.contains(BookmarkStage1Property.rating),
          showHistory:
              _visibleProperties.contains(BookmarkStage1Property.history),
          propertyOrder: _visiblePropertyTokens,
          personRoleGroups: _roleGroups(snapshot.data ?? const []),
          onTap: () => _selectBookmark(bookmark),
          onToggleFavorite: () => widget.repository.toggleFavorite(bookmark),
          menu: _bookmarkMenu(bookmark),
        );
        return Draggable<int>(
          data: bookmark.id,
          feedback: Material(
            elevation: 8,
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 220,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  bookmark.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: .35, child: card),
          child: card,
        );
      },
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
          final scheme = Theme.of(context).colorScheme;
          return MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
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
        },
      );

  Widget _image(
    BookmarkItem bookmark, {
    double width = 60,
    double height = 44,
  }) {
    if (bookmark.coverPhoto != null) {
      return Image.file(
        File(bookmark.coverPhoto!.path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _networkImage(bookmark, width, height),
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
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.image_outlined)),
      );
    }
    return const Center(child: Icon(Icons.image_outlined));
  }

  String _roleValue(List<PersonRoleAssignment> assignments, String role) =>
      assignments
          .where((assignment) => assignment.role == role)
          .map((assignment) => assignment.person.name)
          .join(', ');

  List<String> _orderedListDetails(
    BookmarkItem bookmark,
    List<PersonRoleAssignment> assignments,
  ) {
    final details = <String>[];
    for (final token in _visiblePropertyTokens) {
      if (token.startsWith('role:')) {
        final role = token.substring(5);
        final value = _roleValue(assignments, role);
        if (value.isNotEmpty) details.add('$role: $value');
        continue;
      }
      final property = bookmarkPropertyFromKey(token);
      if (property == null) continue;
      switch (property) {
        case BookmarkStage1Property.image:
          break;
        case BookmarkStage1Property.url:
          details.add(_compactUrl(bookmark.url));
        case BookmarkStage1Property.tags:
          if (bookmark.tags.isNotEmpty) {
            details.add(bookmark.tags.map((tag) => tag.name).join(', '));
          }
        case BookmarkStage1Property.people:
          if (bookmark.people.isNotEmpty) {
            details.add(bookmark.people.map((person) => person.name).join(', '));
          }
        case BookmarkStage1Property.description:
          if (bookmark.description?.trim().isNotEmpty == true) {
            details.add(bookmark.description!);
          }
        case BookmarkStage1Property.createdAt:
          details.add(_formatDate(bookmark.createdAt));
        case BookmarkStage1Property.favorite:
          if (bookmark.favorite) details.add('お気に入り');
        case BookmarkStage1Property.status:
          details.add(bookmarkStatusLabels[bookmark.status] ?? bookmark.status);
        case BookmarkStage1Property.rating:
          if (bookmark.rating > 0) details.add('★' * bookmark.rating);
        case BookmarkStage1Property.history:
          details.add(_historyText(bookmark));
      }
    }
    return details;
  }

  Widget _list(List<BookmarkItem> bookmarks) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
        itemCount: bookmarks.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == bookmarks.length) {
            return DatabaseActionRow(
              label: '新しいブックマーク',
              icon: Icons.add,
              onPressed: () => showBookmarkCreateDialog(
                context: context,
                repository: widget.repository,
              ),
            );
          }
          final bookmark = bookmarks[index];
          return StreamBuilder<List<PersonRoleAssignment>>(
            stream: widget.repository.watchPersonRoles(bookmark),
            builder: (context, roleSnapshot) {
              final assignments =
                  roleSnapshot.data ?? const <PersonRoleAssignment>[];
              final tile = Material(
                color: Colors.transparent,
                child: ListTile(
                  selected: _selectionMode
                      ? _batchSelectedIds.contains(bookmark.id)
                      : bookmark.id == _selectedBookmarkId,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onTap: () => _selectBookmark(bookmark),
                  leading: _selectionMode
                      ? Checkbox(
                          value: _batchSelectedIds.contains(bookmark.id),
                          onChanged: (_) => _selectBookmark(bookmark),
                        )
                      : _visibleProperties.contains(BookmarkStage1Property.image)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 60,
                                height: 44,
                                child: _image(bookmark),
                              ),
                            )
                          : null,
                  title: Text(bookmark.title),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: BookmarkListMetadata(
                      bookmark: bookmark,
                      assignments: assignments,
                      propertyTokens: _visiblePropertyTokens,
                    ),
                  ),
                  trailing: _selectionMode
                      ? null
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_visibleProperties
                              .contains(BookmarkStage1Property.favorite))
                            IconButton(
                              tooltip: 'お気に入り',
                              onPressed: () =>
                                  widget.repository.toggleFavorite(bookmark),
                              icon: Icon(
                                bookmark.favorite
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 19,
                              ),
                            ),
                          _bookmarkMenu(bookmark),
                        ]),
                ),
              );
              return Draggable<int>(
                data: bookmark.id,
                feedback: Material(
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(bookmark.title),
                  ),
                ),
                childWhenDragging: Opacity(opacity: .35, child: tile),
                child: tile,
              );
            },
          );
        },
      );

  Widget _roleCell(BookmarkItem bookmark, String role) =>
      StreamBuilder<List<PersonRoleAssignment>>(
        stream: widget.repository.watchPersonRoles(bookmark),
        builder: (context, snapshot) {
          final names = (snapshot.data ?? const [])
              .where((assignment) => assignment.role == role)
              .map((assignment) => assignment.person.name)
              .join(', ');
          return Text(names);
        },
      );

  Widget _table(List<BookmarkItem> bookmarks) {
    final properties = _orderedVisibleProperties;
    final roles = _orderedVisibleRoles;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: _selectionMode,
        columns: [
          const DataColumn(label: Text('タイトル')),
          ...properties.map(
            (property) => DataColumn(
              label: Text(bookmarkPropertyLabel(property)),
            ),
          ),
          ...roles.map((role) => DataColumn(label: Text(role))),
          const DataColumn(label: Text('')),
        ],
        rows: bookmarks.map((bookmark) {
          final cells = <DataCell>[DataCell(Text(bookmark.title))];
          for (final property in properties) {
            cells.add(switch (property) {
              BookmarkStage1Property.image => DataCell(
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 58,
                      height: 38,
                      child: _image(bookmark, width: 58, height: 38),
                    ),
                  ),
                ),
              BookmarkStage1Property.url =>
                DataCell(Text(_compactUrl(bookmark.url))),
              BookmarkStage1Property.tags => DataCell(
                  Text(bookmark.tags.map((tag) => tag.name).join(', ')),
                ),
              BookmarkStage1Property.people => DataCell(
                  Text(bookmark.people.map((person) => person.name).join(', ')),
                ),
              BookmarkStage1Property.description => DataCell(
                  SizedBox(
                    width: 260,
                    child: Text(
                      bookmark.description ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              BookmarkStage1Property.createdAt =>
                DataCell(Text(_formatDate(bookmark.createdAt))),
              BookmarkStage1Property.favorite => DataCell(
                  IconButton(
                    onPressed: () => widget.repository.toggleFavorite(bookmark),
                    icon: Icon(
                      bookmark.favorite ? Icons.star : Icons.star_border,
                      size: 18,
                    ),
                  ),
                ),
              BookmarkStage1Property.status => DataCell(
                  Text(bookmarkStatusLabels[bookmark.status] ?? bookmark.status),
                ),
              BookmarkStage1Property.rating => DataCell(
                  Text(bookmark.rating == 0 ? '' : '★' * bookmark.rating),
                ),
              BookmarkStage1Property.history =>
                DataCell(Text(_historyText(bookmark))),
            });
          }
          for (final role in roles) {
            cells.add(DataCell(_roleCell(bookmark, role)));
          }
          cells.add(
            DataCell(
              _selectionMode
                  ? const SizedBox.shrink()
                  : _bookmarkMenu(bookmark),
            ),
          );
          return DataRow(
            selected: _selectionMode
                ? _batchSelectedIds.contains(bookmark.id)
                : bookmark.id == _selectedBookmarkId,
            onSelectChanged: (_) => _selectBookmark(bookmark),
            cells: cells,
          );
        }).toList(),
      ),
    );
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_formatDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _historyText(BookmarkItem bookmark) => bookmark.lastOpenedAt == null
      ? '${bookmark.openCount}回 · 未閲覧'
      : '${bookmark.openCount}回 · ${_formatDateTime(bookmark.lastOpenedAt!)}';

  String _visiblePropertiesString() => _visiblePropertyTokens.join(',');

  Future<void> _showPropertiesDialog() async {
    final result = await showBookmarkPropertyOrderDialog(
      context: context,
      currentOrder: _propertyOrder,
      visibleProperties: _visibleProperties,
      visibleRoles: _visiblePersonRoles,
    );
    if (result == null || !mounted) return;
    setState(() {
      _propertyOrder = result.order;
      _visibleProperties
        ..clear()
        ..addAll(result.visibleProperties);
      _visiblePersonRoles
        ..clear()
        ..addAll(result.visibleRoles);
      _markViewChanged();
    });
  }

  Future<void> _showFilterDialog() async {
    final allTags = await widget.repository.watchTags().first;
    if (!mounted) return;
    var favorites = _favoritesOnly;
    var status = _statusFilter;
    var minRating = _minRating;
    var tagMatchMode = _tagMatchMode;
    var includeDescendants = _includeDescendants;
    var selectedTagIds = {..._selectedTagIds};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('フィルター'),
          content: SizedBox(
            width: 390,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sell_outlined, size: 19),
                title: const Text('タグ'),
                subtitle: Text(
                  selectedTagIds.isEmpty
                      ? 'すべて'
                      : allTags
                          .where((tag) => selectedTagIds.contains(tag.id))
                          .map((tag) => tag.name)
                          .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final selected = await showTagDatabasePicker(
                    context: dialogContext,
                    tags: allTags,
                    initiallySelectedIds: selectedTagIds,
                    onCreateTag: _createTagFromPicker,
                  );
                  if (selected != null && dialogContext.mounted) {
                    setLocalState(() {
                      selectedTagIds = selected.map((tag) => tag.id).toSet();
                    });
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('お気に入りのみ'),
                value: favorites,
                onChanged: (value) => setLocalState(() => favorites = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('子タグを含める'),
                value: includeDescendants,
                onChanged: (value) =>
                    setLocalState(() => includeDescendants = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: tagMatchMode,
                decoration: const InputDecoration(labelText: '複数タグの条件'),
                items: const [
                  DropdownMenuItem(
                    value: 'or',
                    child: Text('いずれかを含む（OR）'),
                  ),
                  DropdownMenuItem(
                    value: 'and',
                    child: Text('すべてを含む（AND）'),
                  ),
                ],
                onChanged: (value) =>
                    setLocalState(() => tagMatchMode = value ?? 'or'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'ステータス'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('すべて')),
                  ...bookmarkStatusLabels.entries.map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setLocalState(() => status = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: minRating,
                decoration: const InputDecoration(labelText: '最低評価'),
                items: List.generate(
                  6,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(
                      index == 0 ? '指定なし' : '${'★' * index} 以上',
                    ),
                  ),
                ),
                onChanged: (value) =>
                    setLocalState(() => minRating = value ?? 0),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _favoritesOnly = favorites;
                  _statusFilter = status;
                  _minRating = minRating;
                  _tagMatchMode = tagMatchMode;
                  _includeDescendants = includeDescendants;
                  _selectedTagIds
                    ..clear()
                    ..addAll(selectedTagIds);
                  _markViewChanged();
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

  Future<String?> _askName(
    String title, {
    String initialValue = '',
  }) async {
    var value = initialValue;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  String get _layoutKey => switch (_viewType) {
        BookmarkStage1ViewType.gallery => 'gallery',
        BookmarkStage1ViewType.list => 'list',
        BookmarkStage1ViewType.table => 'table',
      };

  String get _sortKey => switch (_sortField) {
        BookmarkStage1SortField.createdAt => 'createdAt',
        BookmarkStage1SortField.title => 'title',
        BookmarkStage1SortField.url => 'url',
      };

  Future<void> _saveCurrentView() async {
    final name = await _askName('ビューを保存');
    if (name?.isNotEmpty != true) return;
    final id = await widget.repository.createSavedView(
      name: name!,
      layoutType: _layoutKey,
      searchQuery: _query,
      favoritesOnly: _favoritesOnly,
      tagIds: _selectedTagIds,
      tagMatchMode: _tagMatchMode,
      includeDescendants: _includeDescendants,
      personFilterId: _personFilterId,
      photoFilterId: _photoFilterId,
      sortField: _sortKey,
      sortDirection: _sortAscending ? 'asc' : 'desc',
      visibleProperties: _visiblePropertiesString(),
      statusFilter: _statusFilter,
      minRating: _minRating,
    );
    if (mounted) setState(() => _activeSavedViewId = id);
  }

  Future<void> _updateActiveView() async {
    final id = _activeSavedViewId;
    if (id == null) return _saveCurrentView();
    final views = await widget.repository.watchSavedViews().first;
    final matches = views.where((config) => config.view.id == id);
    if (matches.isEmpty) return;
    final config = matches.first;
    await widget.repository.updateSavedView(
      id: id,
      name: config.view.name,
      layoutType: _layoutKey,
      searchQuery: _query,
      favoritesOnly: _favoritesOnly,
      tagIds: _selectedTagIds,
      tagMatchMode: _tagMatchMode,
      includeDescendants: _includeDescendants,
      personFilterId: _personFilterId,
      photoFilterId: _photoFilterId,
      sortField: _sortKey,
      sortDirection: _sortAscending ? 'asc' : 'desc',
      visibleProperties: _visiblePropertiesString(),
      statusFilter: _statusFilter,
      minRating: _minRating,
    );
  }

  Future<void> _duplicateSavedView(SavedViewConfig config) async {
    final name = await _askName(
      'ビューを複製',
      initialValue: '${config.view.name} のコピー',
    );
    if (name?.isNotEmpty != true) return;
    final id = await widget.repository.duplicateSavedView(
      config,
      name: name!,
    );
    if (mounted) setState(() => _activeSavedViewId = id);
  }

  void _applySavedView(SavedViewConfig config) {
    final tokens = config.view.visibleProperties
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final base = <BookmarkStage1Property>{};
    final roles = <String>{};
    for (final key in tokens) {
      if (key.startsWith('role:')) {
        roles.add(key.substring(5));
      } else {
        final property = bookmarkPropertyFromKey(key);
        if (property != null) base.add(property);
      }
    }
    _searchController.text = config.view.searchQuery;
    setState(() {
      _query = config.view.searchQuery;
      _favoritesOnly = config.view.favoritesOnly;
      _statusFilter = config.view.statusFilter;
      _minRating = config.view.minRating;
      _tagMatchMode = config.view.tagMatchMode;
      _includeDescendants = config.view.includeDescendants;
      _personFilterId = config.view.personFilterId;
      _photoFilterId = config.view.photoFilterId;
      _selectedTagIds
        ..clear()
        ..addAll(config.tags.map((tag) => tag.id));
      _sortAscending = config.view.sortDirection == 'asc';
      _sortField = switch (config.view.sortField) {
        'title' => BookmarkStage1SortField.title,
        'url' => BookmarkStage1SortField.url,
        _ => BookmarkStage1SortField.createdAt,
      };
      _viewType = switch (config.view.layoutType) {
        'list' => BookmarkStage1ViewType.list,
        'table' => BookmarkStage1ViewType.table,
        _ => BookmarkStage1ViewType.gallery,
      };
      _propertyOrder = normalizeBookmarkPropertyOrder(tokens);
      _visibleProperties
        ..clear()
        ..addAll(base);
      _visiblePersonRoles
        ..clear()
        ..addAll(roles);
      _activeSavedViewId = config.view.id;
      _relationFilterLabel = null;
    });
  }

  Future<void> _deleteSavedView(SavedViewConfig config) async {
    await widget.repository.deleteSavedView(config.view.id);
    if (mounted && _activeSavedViewId == config.view.id) {
      setState(() => _activeSavedViewId = null);
    }
  }

  Future<Tag?> _createTagFromPicker(String name, Tag? parent) async {
    final id = await widget.repository.createTag(name, parent: parent);
    final tags = await widget.repository.watchTags().first;
    return tags.where((tag) => tag.id == id).firstOrNull;
  }

  Future<Person?> _createPersonFromPicker(String name, String? note) async {
    final id = await widget.repository.createPerson(name, note: note);
    final people = await widget.repository.watchPeople().first;
    return people.where((person) => person.id == id).firstOrNull;
  }

  Future<void> _batchTags({required bool remove}) async {
    final tags = await widget.repository.watchTags().first;
    if (!mounted) return;
    final selected = await showTagDatabasePicker(
      context: context,
      tags: tags,
      initiallySelectedIds: const [],
      onCreateTag: remove ? null : _createTagFromPicker,
    );
    if (selected == null || selected.isEmpty) return;
    if (remove) {
      await widget.repository.batchRemoveTags(
        _batchSelectedIds,
        selected.map((tag) => tag.name),
      );
    } else {
      await widget.repository.batchAddTags(
        _batchSelectedIds,
        selected.map((tag) => tag.name),
      );
    }
  }

  Future<void> _batchPeople({required bool remove}) async {
    final people = await widget.repository.watchPeople().first;
    if (!mounted) return;
    final selected = await showPeopleDatabasePicker(
      context: context,
      people: people,
      initiallySelectedIds: const [],
      onCreatePerson: remove ? null : _createPersonFromPicker,
    );
    if (selected == null || selected.isEmpty) return;
    if (remove) {
      await widget.repository.batchRemovePeople(
        _batchSelectedIds,
        selected.map((person) => person.name),
      );
    } else {
      await widget.repository.batchAddPeople(
        _batchSelectedIds,
        selected.map((person) => person.name),
      );
    }
  }

  Future<void> _batchDelete() async {
    if (_batchSelectedIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_batchSelectedIds.length}件を削除しますか？'),
        content: const Text('選択したブックマークをゴミ箱へ移動します。'),
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
    if (ok == true) {
      final selectedIds = {..._batchSelectedIds};
      final selectedItems = (await widget.repository.watchAll().first)
          .where((bookmark) => selectedIds.contains(bookmark.id))
          .toList();
      await widget.repository.batchDelete(selectedIds);
      if (!mounted) return;
      setState(() {
        _batchSelectedIds.clear();
        _selectionMode = false;
      });
      showAppToast(
        context,
        '${selectedItems.length}件をゴミ箱へ移動しました',
        actionLabel: '元に戻す',
        onAction: () async {
          for (final bookmark in selectedItems) {
            await widget.repository.restoreFromTrash(bookmark);
          }
        },
      );
    }
  }

  Widget _batchBar(List<BookmarkItem> visible) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 2,
        children: [
          Checkbox(
            value: visible.isNotEmpty &&
                visible.every((item) => _batchSelectedIds.contains(item.id)),
            onChanged: (value) => setState(() {
              if (value == true) {
                _batchSelectedIds.addAll(visible.map((item) => item.id));
              } else {
                _batchSelectedIds.removeAll(visible.map((item) => item.id));
              }
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${_batchSelectedIds.length}件',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
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
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Relation編集'),
            ),
          ),
          TextButton.icon(
            onPressed: _batchSelectedIds.isEmpty ? null : _moveBatch,
            icon: const Icon(Icons.drive_file_move_outline, size: 17),
            label: const Text('Workspaceへ移動'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) =>
                widget.repository.batchSetStatus(_batchSelectedIds, value),
            itemBuilder: (_) => bookmarkStatusLabels.entries
                .map(
                  (entry) => PopupMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('ステータス'),
            ),
          ),
          IconButton(
            tooltip: '選択を削除',
            onPressed: _batchSelectedIds.isEmpty ? null : _batchDelete,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: '選択を終了',
            onPressed: _toggleSelectionMode,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _viewSwitcher() => SegmentedButton<BookmarkStage1ViewType>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: BookmarkStage1ViewType.gallery,
            icon: Icon(Icons.grid_view, size: 17),
          ),
          ButtonSegment(
            value: BookmarkStage1ViewType.list,
            icon: Icon(Icons.view_list, size: 17),
          ),
          ButtonSegment(
            value: BookmarkStage1ViewType.table,
            icon: Icon(Icons.table_rows, size: 17),
          ),
        ],
        selected: {_viewType},
        onSelectionChanged: (value) => setState(() {
          _viewType = value.first;
          _markViewChanged();
        }),
      );

  Widget _toolbar() {
    final filterCount = (_favoritesOnly ? 1 : 0) +
        (_statusFilter.isNotEmpty ? 1 : 0) +
        (_minRating > 0 ? 1 : 0) +
        (_relationFilterLabel == null ? 0 : 1);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final searchWidth = (constraints.maxWidth * .26)
            .clamp(150.0, compact ? 190.0 : 240.0)
            .toDouble();
        return Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_alt_outlined, size: 17),
                  label: compact
                      ? const SizedBox.shrink()
                      : Text(
                          filterCount == 0
                              ? 'フィルター'
                              : 'フィルター $filterCount',
                        ),
                ),
                PopupMenuButton<BookmarkStage1SortField>(
                  tooltip: '並べ替え',
                  initialValue: _sortField,
                  onSelected: (value) => setState(() {
                    _sortField = value;
                    _markViewChanged();
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: BookmarkStage1SortField.createdAt,
                      child: Text('登録日時'),
                    ),
                    PopupMenuItem(
                      value: BookmarkStage1SortField.title,
                      child: Text('タイトル'),
                    ),
                    PopupMenuItem(
                      value: BookmarkStage1SortField.url,
                      child: Text('URL'),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.swap_vert, size: 17),
                      SizedBox(width: 6),
                      Text('並べ替え'),
                    ]),
                  ),
                ),
                IconButton(
                  tooltip: _sortAscending ? '昇順' : '降順',
                  onPressed: () => setState(() {
                    _sortAscending = !_sortAscending;
                    _markViewChanged();
                  }),
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18,
                  ),
                ),
                if (!compact)
                  TextButton.icon(
                    onPressed: _showPropertiesDialog,
                    icon: const Icon(Icons.tune, size: 17),
                    label: const Text('プロパティ'),
                  ),
                if (!compact)
                  TextButton.icon(
                    onPressed: _toggleSelectionMode,
                    icon: const Icon(Icons.check_box_outlined, size: 17),
                    label: const Text('選択'),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'ビュー',
                  onSelected: (value) {
                    if (value == 'new') _saveCurrentView();
                    if (value == 'properties') _showPropertiesDialog();
                    if (value == 'select') _toggleSelectionMode();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'new',
                      child: Text('現在のビューを保存'),
                    ),
                    if (compact) ...const [
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'properties',
                        child: Text('プロパティ'),
                      ),
                      PopupMenuItem(
                        value: 'select',
                        child: Text('複数選択'),
                      ),
                    ],
                  ],
                  icon: const Icon(Icons.bookmark_add_outlined, size: 19),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          _viewSwitcher(),
          const SizedBox(width: 10),
          SizedBox(
            width: searchWidth,
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {
                _query = value;
                _markViewChanged();
              }),
              decoration: InputDecoration(
                hintText: '検索',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _markViewChanged();
                          });
                        },
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _tagTree(List<Tag> allTags, int? parentId, int depth) {
    final children = _childrenOf(parentId, allTags);
    return Column(
      children: children.map((tag) {
        final nested = _childrenOf(tag.id, allTags);
        return Column(children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.only(
                left: 8 + depth * 16,
                right: 6,
              ),
              leading: Icon(
                nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined,
                size: 17,
              ),
              title: Text(
                tag.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              selected: _selectedTagIds.length == 1 &&
                  _selectedTagIds.contains(tag.id),
              onTap: () => _filterByTag(tag),
            ),
          ),
          if (nested.isNotEmpty) _tagTree(allTags, tag.id, depth + 1),
        ]);
      }).toList(),
    );
  }

  Widget _savedViewsSection() => StreamBuilder<List<SavedViewConfig>>(
        stream: widget.repository.watchSavedViews(),
        builder: (context, snapshot) {
          final views = snapshot.data ?? const <SavedViewConfig>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 10, 0, 3),
                child: Row(children: [
                  const Expanded(
                    child: Text(
                      '保存ビュー',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '現在のビューを保存',
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: _saveCurrentView,
                    icon: const Icon(Icons.add),
                  ),
                ]),
              ),
              ...views.map(
                (config) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.only(left: 8, right: 0),
                    leading: Icon(
                      config.view.layoutType == 'table'
                          ? Icons.table_rows
                          : config.view.layoutType == 'list'
                              ? Icons.view_list
                              : Icons.grid_view,
                      size: 16,
                    ),
                    title: Text(
                      config.view.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    selected: _activeSavedViewId == config.view.id,
                    onTap: () => _applySavedView(config),
                    trailing: PopupMenuButton<String>(
                      iconSize: 15,
                      onSelected: (value) {
                        if (value == 'delete') _deleteSavedView(config);
                        if (value == 'duplicate') _duplicateSavedView(config);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Text('ビューを複製'),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'delete', child: Text('削除')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget _sidebar(List<Tag> allTags) {
    final scheme = Theme.of(context).colorScheme;
    if (_sidebarCollapsed) {
      return Material(
        color: scheme.surfaceContainerLow,
        child: SizedBox(
          width: 42,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                tooltip: 'サイドバーを開く',
                onPressed: () => setState(() => _sidebarCollapsed = false),
                icon: const Icon(Icons.chevron_right, size: 19),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: 220,
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
            Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.all_inbox_outlined, size: 18),
                title: const Text('すべて'),
                onTap: _resetFilters,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
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
                    _markViewChanged();
                  });
                },
              ),
            ),
            _savedViewsSection(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 0, 4),
              child: Row(children: [
                const Expanded(
                  child: Text(
                    'タグ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Transform.scale(
                  scale: .78,
                  child: Switch(
                    value: _includeDescendants,
                    onChanged: (value) =>
                        setState(() => _includeDescendants = value),
                  ),
                ),
              ]),
            ),
            _tagTree(allTags, null, 0),
          ],
        ),
      ),
    );
  }

  String? _extractUrl(String? rawText, List<String> paths) {
    final raw = rawText?.trim() ?? '';
    final match = RegExp(r'https?://[^\s<>\"]+').firstMatch(raw);
    if (match != null) return match.group(0);
    for (final path in paths) {
      final lower = path.toLowerCase();
      try {
        if (lower.endsWith('.url')) {
          final text = File(path).readAsStringSync();
          final line = text.split('\n').firstWhere(
                (line) => line.trim().toUpperCase().startsWith('URL='),
                orElse: () => '',
              );
          if (line.isNotEmpty) {
            return line.substring(line.indexOf('=') + 1).trim();
          }
        }
        if (lower.endsWith('.webloc')) {
          final text = File(path).readAsStringSync();
          final match = RegExp(r'<string>(https?://.*?)</string>').firstMatch(text);
          if (match != null) return match.group(1);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _handleExternalDrop(DropDoneDetails details) async {
    setState(() => _externalDragging = false);
    final paths = details.files
        .map((file) => file.path)
        .where((path) => path.isNotEmpty)
        .toList();
    final imagePaths = paths.where((path) {
      final lower = path.toLowerCase();
      return const [
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.gif',
        '.heic',
        '.heif',
      ].any(lower.endsWith);
    }).toList();

    if (imagePaths.isNotEmpty) {
      final imported = await const PhotoStorageService().importPaths(imagePaths);
      for (final photo in imported) {
        await widget.repository.addPhoto(
          path: photo.path,
          title: photo.originalName,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${imported.length}枚を写真DBへ追加しました')),
        );
      }
    }

    final url = _extractUrl(details.rawText, paths);
    if (url != null) {
      final duplicate = await widget.repository.findDuplicateUrl(url);
      if (duplicate != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('同じURL「${duplicate.title}」がすでにあります')),
          );
        }
        return;
      }
      try {
        final metadata = await const BookmarkMetadataService().fetch(url);
        await widget.repository.create(
          url: metadata.url,
          title: metadata.title,
          thumbnail: metadata.thumbnail,
          description: metadata.description,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ドロップしたURLを追加しました')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('URLを追加できませんでした: $error')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tag>>(
      stream: widget.repository.watchTags(),
      builder: (context, tagSnapshot) {
        final tags = tagSnapshot.data ?? const <Tag>[];
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            toolbarHeight: 50,
            title: Column(mainAxisSize: MainAxisSize.min, children: [
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bookmarks_outlined, size: 19),
                SizedBox(width: 6),
                Text(
                  'Bookmarks',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
              ]),
              Text(
                '${widget.profileName} / ${widget.workspaceName}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ]),
          ),
          floatingActionButton:
              _selectionMode || _viewType != BookmarkStage1ViewType.table
                  ? null
                  : FloatingActionButton.extended(
                  onPressed: () => showBookmarkCreateDialog(
                    context: context,
                    repository: widget.repository,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
          body: DropTarget(
            onDragEntered: (_) => setState(() => _externalDragging = true),
            onDragExited: (_) => setState(() => _externalDragging = false),
            onDragDone: _handleExternalDrop,
            child: StreamBuilder<List<BookmarkItem>>(
              stream: widget.repository.watchAll(),
              builder: (context, bookmarkSnapshot) {
                if (!bookmarkSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allBookmarks = bookmarkSnapshot.data!;
                final bookmarks = _applyFilters(allBookmarks, tags);
                final selected = allBookmarks
                    .where((bookmark) => bookmark.id == _selectedBookmarkId)
                    .firstOrNull;
                return LayoutBuilder(builder: (context, constraints) {
                  final wantsDetail = selected != null && !_selectionMode;
                  // Database navigation now lives in the Notion-style
                  // view tabs above the toolbar, avoiding a second sidebar.
                  const showSidebar = false;
                  final fixedSidebarWidth = showSidebar
                      ? (_sidebarCollapsed ? 43.0 : 221.0)
                      : 0.0;
                  final availableForDetail =
                      constraints.maxWidth - fixedSidebarWidth - 260;
                  final showDetail =
                      wantsDetail && availableForDetail >= 320;
                  final maxDetailWidth = showDetail
                      ? availableForDetail.clamp(320.0, 720.0).toDouble()
                      : 0.0;
                  final effectiveDetailWidth = showDetail
                      ? _detailWidth.clamp(320.0, maxDetailWidth).toDouble()
                      : 0.0;

                  return Stack(children: [
                    Row(children: [
                      if (showSidebar) ...[
                        _sidebar(tags),
                        VerticalDivider(
                          width: 1,
                          color: scheme.outlineVariant,
                        ),
                      ],
                      Expanded(
                        child: Column(children: [
                          _databaseViewTabs(),
                          _toolbar(),
                          if (_selectionMode) _batchBar(bookmarks),
                          Expanded(
                            child: bookmarks.isEmpty
                                ? const Center(
                                    child: Text('条件に一致するブックマークがありません'),
                                  )
                                : switch (_viewType) {
                                    BookmarkStage1ViewType.gallery =>
                                      _gallery(bookmarks),
                                    BookmarkStage1ViewType.list =>
                                      _list(bookmarks),
                                    BookmarkStage1ViewType.table =>
                                      _table(bookmarks),
                                  },
                          ),
                        ]),
                      ),
                      if (showDetail) ...[
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) => setState(
                              () => _detailWidth =
                                  (_detailWidth - details.delta.dx)
                                      .clamp(320.0, 720.0),
                            ),
                            child: Container(
                              width: 6,
                              color: scheme.outlineVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: effectiveDetailWidth,
                          child: BookmarkDetailPanel(
                            key: ValueKey(selected.id),
                            repository: widget.repository,
                            bookmark: selected,
                            onClose: () =>
                                setState(() => _selectedBookmarkId = null),
                            onFilterByTag: _filterByTag,
                            onFilterByPerson: _filterByPerson,
                            onFilterByPhoto: _filterByPhoto,
                          ),
                        ),
                      ],
                    ]),
                    if (_externalDragging)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: scheme.scrim.withValues(alpha: .30),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: scheme.outline),
                              ),
                              child: const Text(
                                'URLまたは画像をドロップして追加',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]);
                });
              },
            ),
          ),
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
