import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../widgets/bookmark_create_dialog.dart';

class BookmarkLifecyclePage extends StatelessWidget {
  const BookmarkLifecyclePage.inbox({
    super.key,
    required this.repository,
  }) : mode = BookmarkLifecycleMode.inbox;

  const BookmarkLifecyclePage.archive({
    super.key,
    required this.repository,
  }) : mode = BookmarkLifecycleMode.archive;

  const BookmarkLifecyclePage.trash({
    super.key,
    required this.repository,
  }) : mode = BookmarkLifecycleMode.trash;

  final BookmarkRepository repository;
  final BookmarkLifecycleMode mode;

  String get _title => switch (mode) {
        BookmarkLifecycleMode.inbox => 'Inbox',
        BookmarkLifecycleMode.archive => 'アーカイブ',
        BookmarkLifecycleMode.trash => 'ゴミ箱',
      };

  IconData get _icon => switch (mode) {
        BookmarkLifecycleMode.inbox => Icons.inbox_outlined,
        BookmarkLifecycleMode.archive => Icons.archive_outlined,
        BookmarkLifecycleMode.trash => Icons.delete_outline,
      };

  Stream<List<BookmarkItem>> _stream() => switch (mode) {
        BookmarkLifecycleMode.inbox => repository.watchInbox(),
        BookmarkLifecycleMode.archive => repository.watchAll().map(
            (items) => items.where((item) => item.status == 'archived').toList(),
          ),
        BookmarkLifecycleMode.trash => repository.watchTrash(),
      };

  Future<void> _open(BookmarkItem bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null) return;
    await repository.recordOpen(bookmark);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(_icon, size: 19), const SizedBox(width: 7), Text(_title)],
        ),
      ),
      floatingActionButton: mode == BookmarkLifecycleMode.inbox
          ? FloatingActionButton.extended(
              onPressed: () => showBookmarkCreateDialog(
                context: context,
                repository: repository,
                initialInbox: true,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Inboxに追加'),
            )
          : null,
      body: StreamBuilder<List<BookmarkItem>>(
        stream: _stream(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <BookmarkItem>[];
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return Center(
              child: Text(
                switch (mode) {
                  BookmarkLifecycleMode.inbox => 'Inboxは空です',
                  BookmarkLifecycleMode.archive => 'アーカイブはありません',
                  BookmarkLifecycleMode.trash => 'ゴミ箱は空です',
                },
                style: const TextStyle(color: Color(0xFF9B9A97)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 90),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bookmark = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: bookmark.coverPhoto == null
                    ? const SizedBox(
                        width: 52,
                        height: 40,
                        child: Icon(Icons.bookmark_outline),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(bookmark.coverPhoto!.path),
                          width: 52,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            width: 52,
                            height: 40,
                            child: Icon(Icons.bookmark_outline),
                          ),
                        ),
                      ),
                title: Text(bookmark.title),
                subtitle: Text(
                  [
                    bookmark.url,
                    if (bookmark.tags.isNotEmpty)
                      bookmark.tags.map((e) => e.name).join(', '),
                  ].join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: mode == BookmarkLifecycleMode.trash ? null : () => _open(bookmark),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'open') await _open(bookmark);
                    if (value == 'inbox_done') await repository.setInbox(bookmark, false);
                    if (value == 'archive') {
                      await repository.setInbox(bookmark, false);
                      await repository.setStatus(bookmark, 'archived');
                    }
                    if (value == 'unarchive') await repository.setStatus(bookmark, 'unread');
                    if (value == 'trash') await repository.moveToTrash(bookmark);
                    if (value == 'restore') await repository.restoreFromTrash(bookmark);
                    if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('完全に削除しますか？'),
                          content: const Text('この操作は元に戻せません。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('キャンセル'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('完全に削除'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await repository.permanentDelete(bookmark);
                    }
                  },
                  itemBuilder: (_) => switch (mode) {
                    BookmarkLifecycleMode.inbox => const [
                        PopupMenuItem(value: 'open', child: Text('ブラウザで開く')),
                        PopupMenuItem(value: 'inbox_done', child: Text('Inboxから出す')),
                        PopupMenuItem(value: 'archive', child: Text('アーカイブ')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'trash', child: Text('ゴミ箱へ移動')),
                      ],
                    BookmarkLifecycleMode.archive => const [
                        PopupMenuItem(value: 'open', child: Text('ブラウザで開く')),
                        PopupMenuItem(value: 'unarchive', child: Text('アーカイブ解除')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'trash', child: Text('ゴミ箱へ移動')),
                      ],
                    BookmarkLifecycleMode.trash => const [
                        PopupMenuItem(value: 'restore', child: Text('復元')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'delete', child: Text('完全に削除')),
                      ],
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum BookmarkLifecycleMode { inbox, archive, trash }
