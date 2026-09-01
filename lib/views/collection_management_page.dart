import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_toast.dart';
import '../widgets/inline_rename_text.dart';
import '../widgets/notion_inline_field.dart';

class CollectionManagementPage extends StatefulWidget {
  const CollectionManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<CollectionManagementPage> createState() => _CollectionManagementPageState();
}

class _CollectionManagementPageState extends State<CollectionManagementPage> {
  int? _selectedCollectionId;
  String _query = '';

  BookmarkRepository get repository => widget.repository;
  AppDatabase get database => repository.workspaceStore.database;

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('コレクションを作成'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '名前を入力して Enter',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('閉じる')),
        ],
      ),
    );
    controller.dispose();
    if (name?.isNotEmpty != true) return;
    final id = await repository.createCollection(name!);
    if (mounted) setState(() => _selectedCollectionId = id);
  }

  Future<void> _rename(CollectionRecord collection, String name) async {
    final value = name.trim();
    if (value.isEmpty || value == collection.name) return;
    await (database.update(database.collections)..where((row) => row.id.equals(collection.id))).write(
      CollectionsCompanion(name: Value(value)),
    );
  }

  Future<void> _saveNote(CollectionRecord collection, String note) async {
    await (database.update(database.collections)..where((row) => row.id.equals(collection.id))).write(
      CollectionsCompanion(note: Value(note.trim().isEmpty ? null : note.trim())),
    );
  }

  Future<void> _delete(CollectionRecord collection) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「${collection.name}」を削除しますか？'),
        content: const Text('ブックマーク自体は削除されません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok != true) return;
    await repository.deleteCollection(collection);
    if (mounted && _selectedCollectionId == collection.id) {
      setState(() => _selectedCollectionId = null);
    }
  }

  Future<void> _addBookmark(int bookmarkId, CollectionRecord collection) async {
    final bookmarks = await repository.watchAll().first;
    final bookmark = bookmarks.where((item) => item.id == bookmarkId).firstOrNull;
    if (bookmark == null || !mounted) return;
    if (bookmark.collections.any((item) => item.id == collection.id)) {
      showAppToast(context, '「${bookmark.title}」はすでに追加されています');
      return;
    }
    await repository.setBookmarkCollections(bookmark, [...bookmark.collections, collection]);
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
              .where((item) => !item.collections.any((candidate) => candidate.id == collection.id))
              .where((item) => q.isEmpty || '${item.title} ${item.url}'.toLowerCase().contains(q))
              .toList();
          return AlertDialog(
            title: const Text('ブックマークを追加'),
            content: SizedBox(
              width: 560,
              height: 480,
              child: Column(children: [
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
                      ? const AppEmptyState(icon: Icons.search_off_outlined, title: '追加できるブックマークがありません')
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              leading: const Icon(Icons.bookmark_outline),
                              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.add, size: 18),
                              onTap: () async {
                                await _addBookmark(item.id, collection);
                                if (dialogContext.mounted) setLocalState(() {});
                              },
                            );
                          },
                        ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('閉じる')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeBookmark(BookmarkItem bookmark, CollectionRecord collection) async {
    final remaining = bookmark.collections.where((item) => item.id != collection.id);
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
            onTap: () => setState(() => _selectedCollectionId = collection.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(children: [
                const Icon(Icons.collections_bookmark_outlined, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    InlineRenameText(
                      value: collection.name,
                      onSubmitted: (value) => _rename(collection, value),
                    ),
                    Text(
                      hovering ? 'ここにドロップして追加' : '$count件のブックマーク',
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ]),
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
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _detail(CollectionRecord collection) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Container(
        height: UiTokens.toolbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        child: Row(children: [
          const Icon(Icons.collections_bookmark_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: InlineRenameText(
              value: collection.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              onSubmitted: (value) => _rename(collection, value),
            ),
          ),
          TextButton.icon(
            onPressed: () => _chooseBookmark(collection),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('追加'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete(collection);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('コレクションを削除')),
            ],
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<List<BookmarkItem>>(
          stream: repository.watchBookmarksForCollection(collection),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
              children: [
                NotionInlineField(
                  value: collection.note ?? '',
                  hintText: '説明を追加…',
                  maxLines: null,
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
                  onSaved: (value) => _saveNote(collection, value),
                ),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  SizedBox(
                    height: 260,
                    child: AppEmptyState(
                      icon: Icons.collections_bookmark_outlined,
                      title: 'まだブックマークはありません',
                      message: '＋から追加するか、ブックマークカードをこのコレクションへドラッグしてください。',
                      actionLabel: 'ブックマークを追加',
                      onAction: () => _chooseBookmark(collection),
                    ),
                  )
                else
                  ...items.map(
                    (item) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.bookmark_outline, size: 18),
                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        tooltip: 'コレクションから外す',
                        icon: const Icon(Icons.close, size: 17),
                        onPressed: () => _removeBookmark(item, collection),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('コレクションを追加'),
      ),
      body: StreamBuilder<List<CollectionRecord>>(
        stream: repository.watchCollections(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          final q = _query.trim().toLowerCase();
          final collections = all.where((item) => q.isEmpty || '${item.name} ${item.note ?? ''}'.toLowerCase().contains(q)).toList();
          final selected = all.where((item) => item.id == _selectedCollectionId).firstOrNull;
          if (all.isEmpty) {
            return AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'コレクションはまだありません',
              message: 'シリーズやテーマごとにブックマークをまとめられます。',
              actionLabel: 'コレクションを作成',
              onAction: _create,
            );
          }
          return Row(children: [
            SizedBox(
              width: selected == null ? 360 : 300,
              child: Column(children: [
                Container(
                  height: UiTokens.toolbarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    const Expanded(child: Text('コレクション', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                    IconButton(tooltip: '追加', onPressed: _create, icon: const Icon(Icons.add, size: 18)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 18),
                      hintText: '検索',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: collections.isEmpty
                      ? const AppEmptyState(icon: Icons.search_off_outlined, title: '一致するコレクションがありません')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: collections.length,
                          itemBuilder: (context, index) {
                            final collection = collections[index];
                            return StreamBuilder<List<BookmarkItem>>(
                              stream: repository.watchBookmarksForCollection(collection),
                              builder: (context, itemSnapshot) => _collectionRow(
                                collection,
                                itemSnapshot.data?.length ?? 0,
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? const AppEmptyState(
                      icon: Icons.collections_bookmark_outlined,
                      title: 'コレクションを選択',
                      message: '左の一覧から開くと、ここで直接編集できます。',
                    )
                  : _detail(selected),
            ),
          ]);
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
