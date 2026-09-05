import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_url_resolver.dart';
import '../widgets/bookmark_create_dialog.dart';
import '../widgets/bookmark_visual_image.dart';

class BookmarkLifecyclePage extends StatelessWidget {
  const BookmarkLifecyclePage.inbox({
    super.key,
    required this.repository,
    this.resolveUrl,
  }) : mode = BookmarkLifecycleMode.inbox;

  const BookmarkLifecyclePage.archive({
    super.key,
    required this.repository,
    this.resolveUrl,
  }) : mode = BookmarkLifecycleMode.archive;

  const BookmarkLifecyclePage.trash({
    super.key,
    required this.repository,
    this.resolveUrl,
  }) : mode = BookmarkLifecycleMode.trash;

  final BookmarkRepository repository;
  final BookmarkLifecycleMode mode;
  final BookmarkUrlResolve? resolveUrl;

  String get _title => switch (mode) {
        BookmarkLifecycleMode.inbox => '未整理',
        BookmarkLifecycleMode.archive => 'アーカイブ',
        BookmarkLifecycleMode.trash => 'ゴミ箱',
      };

  IconData get _icon => switch (mode) {
        BookmarkLifecycleMode.inbox => Icons.inbox_outlined,
        BookmarkLifecycleMode.archive => Icons.archive_outlined,
        BookmarkLifecycleMode.trash => Icons.delete_outline,
      };

  Future<BookmarkUrlSource?> _resolveUrl(BookmarkItem bookmark) {
    final injected = resolveUrl;
    if (injected != null) return injected(bookmark);
    return BookmarkUrlResolver(
      database: repository.workspaceStore.database,
      workspaceId: repository.workspaceId,
    ).resolve(bookmark);
  }

  Stream<List<BookmarkItem>> _stream() => switch (mode) {
        BookmarkLifecycleMode.inbox => repository.watchInbox(),
        BookmarkLifecycleMode.archive => repository.watchArchive(),
        BookmarkLifecycleMode.trash => repository.watchTrash(),
      };

  Future<void> _open(BookmarkItem bookmark) async {
    final resolved = await _resolveUrl(bookmark);
    final uri = resolved == null ? null : Uri.tryParse(resolved.value);
    if (uri == null) return;
    await repository.recordOpen(bookmark);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _addExistingToInbox(BuildContext context) async {
    final all = await repository.watchAll().first;
    final inboxItems = await repository.watchInbox().first;
    final inboxIds = inboxItems.map((item) => item.id).toSet();
    final candidates = all.where((item) => !inboxIds.contains(item.id)).toList();
    if (!context.mounted) return;
    BookmarkItem? selected;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('既存ブックマークを未整理へ'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: candidates.isEmpty
                ? const Center(child: Text('追加できるブックマークがありません'))
                : RadioGroup<int>(
                    groupValue: selected?.id,
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(
                        () => selected = candidates.firstWhere(
                          (item) => item.id == value,
                        ),
                      );
                    },
                    child: ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final item = candidates[index];
                        return RadioListTile<int>(
                          value: item.id,
                          title: Text(item.title),
                          subtitle: _BookmarkLifecycleUrlText(
                            resolveUrl: _resolveUrl,
                            bookmark: item,
                          ),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await repository.setInbox(selected!, true);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('未整理へ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(_icon, size: 19), const SizedBox(width: 7), Text(_title)],
        ),
        actions: mode == BookmarkLifecycleMode.inbox
            ? [
                TextButton.icon(
                  onPressed: () => _addExistingToInbox(context),
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('既存から追加'),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      floatingActionButton: mode == BookmarkLifecycleMode.inbox
          ? FloatingActionButton.extended(
              onPressed: () => showBookmarkCreateDialog(
                context: context,
                repository: repository,
                initialInbox: true,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('未整理に追加'),
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
                  BookmarkLifecycleMode.inbox => '未整理は空です',
                  BookmarkLifecycleMode.archive => 'アーカイブはありません',
                  BookmarkLifecycleMode.trash => 'ゴミ箱は空です',
                },
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: BookmarkVisualImage(
                    repository: repository,
                    bookmark: bookmark,
                    width: 52,
                    height: 40,
                    placeholder: const SizedBox(
                      width: 52,
                      height: 40,
                      child: Icon(Icons.bookmark_outline),
                    ),
                  ),
                ),
                title: Text(bookmark.title),
                subtitle: _BookmarkLifecycleUrlText(
                  resolveUrl: _resolveUrl,
                  bookmark: bookmark,
                  includeTags: true,
                ),
                onTap: mode == BookmarkLifecycleMode.trash ? null : () => _open(bookmark),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'open') await _open(bookmark);
                    if (value == 'inbox_done') await repository.setInbox(bookmark, false);
                    if (value == 'archive') {
                      await repository.setInbox(bookmark, false);
                      await repository.archive(bookmark);
                    }
                    if (value == 'unarchive') await repository.unarchive(bookmark);
                    if (value == 'trash') await repository.moveToTrash(bookmark);
                    if (value == 'restore') await repository.restoreFromTrash(bookmark);
                    if (value == 'delete') {
                      if (!context.mounted) return;
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
                        PopupMenuItem(value: 'inbox_done', child: Text('未整理から出す')),
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

class _BookmarkLifecycleUrlText extends StatefulWidget {
  const _BookmarkLifecycleUrlText({
    required this.resolveUrl,
    required this.bookmark,
    this.includeTags = false,
  });

  final BookmarkUrlResolve resolveUrl;
  final BookmarkItem bookmark;
  final bool includeTags;

  @override
  State<_BookmarkLifecycleUrlText> createState() =>
      _BookmarkLifecycleUrlTextState();
}

class _BookmarkLifecycleUrlTextState extends State<_BookmarkLifecycleUrlText> {
  late Future<BookmarkUrlSource?> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = widget.resolveUrl(widget.bookmark);
  }

  @override
  void didUpdateWidget(covariant _BookmarkLifecycleUrlText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookmark.id != widget.bookmark.id ||
        oldWidget.bookmark.url != widget.bookmark.url ||
        oldWidget.resolveUrl != widget.resolveUrl) {
      _resolved = widget.resolveUrl(widget.bookmark);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BookmarkUrlSource?>(
      future: _resolved,
      builder: (context, snapshot) {
        final url = snapshot.data?.value ?? widget.bookmark.url;
        final values = <String>[
          url,
          if (widget.includeTags && widget.bookmark.tags.isNotEmpty)
            widget.bookmark.tags.map((tag) => tag.name).join(', '),
        ];
        return Text(
          values.join('  ·  '),
          maxLines: widget.includeTags ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

enum BookmarkLifecycleMode { inbox, archive, trash }
