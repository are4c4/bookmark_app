import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/database_view_store.dart';
import '../database/database_definition.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_toast.dart';
import '../widgets/database_create_tiles.dart';
import '../widgets/database_page_toolbar.dart';
import '../widgets/database_view_tabs.dart';
import '../widgets/inline_rename_text.dart';
import '../widgets/notion_inline_field.dart';
import '../widgets/resizable_detail_pane.dart';

class CollectionManagementPage extends StatefulWidget {
  const CollectionManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<CollectionManagementPage> createState() => _CollectionManagementPageState();
}

class _CollectionManagementPageState extends State<CollectionManagementPage> {
  int? _selectedCollectionId;
  String _query = '';
  late final DatabaseViewStore _databaseViewStore;
  DatabaseViewConfig? _activeDatabaseView;
  int? _activeDatabaseViewId;
  Timer? _viewSaveTimer;

  BookmarkRepository get repository => widget.repository;
  AppDatabase get database => repository.workspaceStore.database;

  @override
  void initState() {
    super.initState();
    _databaseViewStore = DatabaseViewStore(database);
  }

  @override
  void dispose() {
    _viewSaveTimer?.cancel();
    super.dispose();
  }

  void _applyDatabaseView(DatabaseViewConfig view) {
    setState(() {
      _activeDatabaseView = view;
      _activeDatabaseViewId = view.id;
      _query = (view.filters['query'] as String?) ?? '';
    });
  }

  void _markDatabaseViewChanged() {
    final active = _activeDatabaseView;
    if (active == null) return;
    _viewSaveTimer?.cancel();
    _viewSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _activeDatabaseViewId != active.id) return;
      final next = active.copyWith(
        layoutType: 'list',
        filters: {'query': _query},
      );
      await _databaseViewStore.updateView(next);
      if (mounted && _activeDatabaseViewId == active.id) _activeDatabaseView = next;
    });
  }

  Widget _databaseViewTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 10, 0),
        child: DatabaseViewTabs(
          store: _databaseViewStore,
          definition: BuiltInDatabases.collections,
          workspaceId: repository.workspaceId,
          activeViewId: _activeDatabaseViewId,
          onSelected: _applyDatabaseView,
        ),
      );

  Future<void> _createInline(String name) async {
    final value = name.trim();
    if (value.isEmpty) return;
    final existing = await repository.watchCollections().first;
    final duplicate = existing.where(
      (collection) => collection.name.trim().toLowerCase() == value.toLowerCase(),
    );
    if (duplicate.isNotEmpty) {
      if (mounted) setState(() => _selectedCollectionId = duplicate.first.id);
      return;
    }
    final id = await repository.createCollection(value);
    if (mounted) setState(() => _selectedCollectionId = id);
  }

  Future<void> _rename(CollectionRecord collection, String name) async {
    final value = name.trim();
    if (value.isEmpty || value == collection.name) return;
    await (database.update(database.collections)
          ..where((row) => row.id.equals(collection.id)))
        .write(CollectionsCompanion(name: Value(value)));
  }

  Future<void> _saveNote(CollectionRecord collection, String note) async {
    await (database.update(database.collections)
          ..where((row) => row.id.equals(collection.id)))
        .write(
      CollectionsCompanion(
        note: Value(note.trim().isEmpty ? null : note.trim()),
      ),
    );
  }

  Future<void> _delete(CollectionRecord collection) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「${collection.name}」を削除しますか？'),
        content: const Text('ブックマーク自体は削除されません。'),
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
    if (ok != true) return;
    await repository.deleteCollection(collection);
    if (mounted && _selectedCollectionId == collection.id) {
      setState(() => _selectedCollectionId = null);
    }
  }

  Future<void> _addBookmark(
    int bookmarkId,
    CollectionRecord collection,
  ) async {
    final bookmarks = await repository.watchAll().first;
    final bookmark = bookmarks
        .where((item) => item.id == bookmarkId)
        .firstOrNull;
    if (bookmark == null || !mounted) return;
    if (bookmark.collections.any((item) => item.id == collection.id)) {
      showAppToast(context, '「${bookmark.title}」はすでに追加されています');
      return;
    }
    await repository.setBookmarkCollections(
      bookmark,
      [...bookmark.collections, collection],
    );
    if (mounted) showAppToast(context, '「${collection.name}」へ追加しました');
  }

  Future<void> _chooseBookmark(CollectionRecord collection) async {
    final all = await repository.watchAll().first;
    if (!mounted) return;
    var query = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final q = query.trim().toLowerCase();
          final items = all
              .where(
                (item) => !item.collections
                    .any((candidate) => candidate.id == collection.id),
              )
              .where(
                (item) => q.isEmpty ||
                    '${item.title} ${item.url}'.toLowerCase().contains(q),
              )
              .toList();
          return AlertDialog(
            title: const Text('ブックマークを追加'),
            content: SizedBox(
              width: 560,
              height: 480,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setLocalState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ブックマークを検索',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: items.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.search_off_outlined,
                            title: '追加できるブックマークがありません',
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return ListTile(
                                leading: const Icon(Icons.bookmark_outline),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  item.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.add, size: 18),
                                onTap: () async {
                                  await _addBookmark(item.id, collection);
                                  if (dialogContext.mounted) {
                                    setLocalState(() {});
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeBookmark(
    BookmarkItem bookmark,
    CollectionRecord collection,
  ) async {
    final remaining = bookmark.collections
        .where((item) => item.id != collection.id);
    await repository.setBookmarkCollections(bookmark, remaining);
    if (mounted) showAppToast(context, 'コレクションから外しました');
  }

  Widget _collectionRow(CollectionRecord collection, int count) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedCollectionId == collection.id;
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _addBookmark(details.data, collection),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Material(
          color: selected
              ? scheme.secondaryContainer.withValues(alpha: .38)
              : hovering
                  ? scheme.surfaceContainerHigh
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () =>
                setState(() => _selectedCollectionId = collection.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.collections_bookmark_outlined, size: 18),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InlineRenameText(
                          value: collection.name,
                          onSubmitted: (value) => _rename(collection, value),
                        ),
                        Text(
                          hovering
                              ? 'ここにドロップして追加'
                              : '$count件のブックマーク',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    iconSize: 17,
                    onSelected: (value) {
                      if (value == 'delete') _delete(collection);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('削除')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detail(CollectionRecord collection) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: UiTokens.toolbarHeight,
            child: Row(
              children: [
                const SizedBox(width: UiTokens.space16),
                const Icon(Icons.collections_bookmark_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: InlineRenameText(
                    value: collection.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    onSubmitted: (value) => _rename(collection, value),
                  ),
                ),
                IconButton(
                  tooltip: 'ブックマークを追加',
                  onPressed: () => _chooseBookmark(collection),
                  icon: const Icon(Icons.add, size: 18),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') _delete(collection);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('コレクションを削除'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: '閉じる',
                  onPressed: () =>
                      setState(() => _selectedCollectionId = null),
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<BookmarkItem>>(
              stream: repository.watchBookmarksForCollection(collection),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 60),
                  children: [
                    NotionInlineField(
                      value: collection.note ?? '',
                      hintText: '説明を追加…',
                      maxLines: null,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: scheme.onSurfaceVariant,
                      ),
                      onSaved: (value) => _saveNote(collection, value),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Text(
                          'ブックマーク',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _chooseBookmark(collection),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('追加'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (items.isEmpty)
                      SizedBox(
                        height: 220,
                        child: AppEmptyState(
                          icon: Icons.collections_bookmark_outlined,
                          title: 'まだブックマークはありません',
                          message:
                              '＋から追加するか、ブックマークカードをここへドラッグしてください。',
                          actionLabel: 'ブックマークを追加',
                          onAction: () => _chooseBookmark(collection),
                        ),
                      )
                    else
                      ...items.map(
                        (item) => ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.bookmark_outline, size: 18),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'コレクションから外す',
                            icon: const Icon(Icons.close, size: 17),
                            onPressed: () =>
                                _removeBookmark(item, collection),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _databaseViewTabs(),
          DatabasePageToolbar(
            title: 'コレクション',
            searchHint: 'コレクションを検索',
            searchValue: _query,
            onSearchChanged: (value) => setState(() {
              _query = value;
              _markDatabaseViewChanged();
            }),
          ),
          Expanded(
            child: StreamBuilder<List<CollectionRecord>>(
              stream: repository.watchCollections(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data!;
                final q = _query.trim().toLowerCase();
                final collections = all
                    .where(
                      (item) => q.isEmpty ||
                          '${item.name} ${item.note ?? ''}'
                              .toLowerCase()
                              .contains(q),
                    )
                    .toList();
                final selected = all
                    .where((item) => item.id == _selectedCollectionId)
                    .firstOrNull;

                return Row(
                  children: [
                    Expanded(
                      child: collections.isEmpty && q.isNotEmpty
                          ? const AppEmptyState(
                              icon: Icons.search_off_outlined,
                              title: '一致するコレクションがありません',
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                              children: [
                                ...collections.map(
                                  (collection) => StreamBuilder<List<BookmarkItem>>(
                                    stream: repository
                                        .watchBookmarksForCollection(collection),
                                    builder: (context, itemSnapshot) =>
                                        _collectionRow(
                                      collection,
                                      itemSnapshot.data?.length ?? 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DatabaseCreateRow(
                                  label: '新しいコレクション',
                                  icon: Icons.add,
                                  hintText: 'コレクション名を入力して Enter',
                                  onCreate: _createInline,
                                ),
                              ],
                            ),
                    ),
                    if (selected != null)
                      ResizableDetailPane(
                        storageKey: 'collection-detail-pane',
                        initialWidth: 430,
                        child: _detail(selected),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
