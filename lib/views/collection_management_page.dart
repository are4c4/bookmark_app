import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';

class CollectionManagementPage extends StatelessWidget {
  const CollectionManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  Future<void> _create(BuildContext context) async {
    var name = '';
    var note = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('コレクション / シリーズを追加'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '名前'),
                  onChanged: (value) => setLocalState(() => name = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'メモ（任意）'),
                  onChanged: (value) => note = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: name.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await repository.createCollection(
        name.trim(),
        note: note.trim().isEmpty ? null : note.trim(),
      );
    }
  }

  Future<void> _showBookmarks(
    BuildContext context,
    CollectionRecord collection,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(collection.name),
        content: SizedBox(
          width: 560,
          height: 440,
          child: StreamBuilder<List<BookmarkItem>>(
            stream: repository.watchBookmarksForCollection(collection),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <BookmarkItem>[];
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return const Center(child: Text('このコレクションのブックマークはありません'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(item.title),
                    subtitle: Text(
                      item.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    CollectionRecord collection,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${collection.name}」を削除しますか？'),
        content: const Text('ブックマーク自体は削除されません。'),
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
    if (ok == true) await repository.deleteCollection(collection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コレクション / シリーズ'),
        actions: [
          TextButton.icon(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<List<CollectionRecord>>(
        stream: repository.watchCollections(),
        builder: (context, snapshot) {
          final collections = snapshot.data ?? const <CollectionRecord>[];
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (collections.isEmpty) {
            return const Center(
              child: Text(
                'コレクションはまだありません',
                style: TextStyle(color: Color(0xFF9B9A97)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: collections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final collection = collections[index];
              return StreamBuilder<List<BookmarkItem>>(
                stream: repository.watchBookmarksForCollection(collection),
                builder: (context, itemSnapshot) {
                  final count = itemSnapshot.data?.length ?? 0;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.collections_bookmark_outlined),
                      ),
                      title: Text(collection.name),
                      subtitle: Text(
                        [
                          '$count件のブックマーク',
                          if (collection.note?.trim().isNotEmpty == true)
                            collection.note!,
                        ].join('  ·  '),
                      ),
                      onTap: () => _showBookmarks(context, collection),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'open') {
                            _showBookmarks(context, collection);
                          }
                          if (value == 'delete') {
                            _delete(context, collection);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'open',
                            child: Text('ブックマークを見る'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'delete', child: Text('削除')),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
