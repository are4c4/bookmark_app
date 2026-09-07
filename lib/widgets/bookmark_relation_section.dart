import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_object_detail_context.dart';
import '../data/bookmark_repository.dart';
import '../features/object/presentation/widgets/object_body_editor_section.dart';
import '../repositories/backlink_repository.dart';
import '../views/object_inspector_page.dart';

const _relationLabels = <String, String>{
  'related': '関連',
  'sequel': '続編',
  'previous': '前編',
  'reference': '参考',
  'source': '元記事 / 元動画',
};

class BookmarkRelationSection extends StatefulWidget {
  const BookmarkRelationSection({
    super.key,
    required this.repository,
    required this.bookmark,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;

  @override
  State<BookmarkRelationSection> createState() => _BookmarkRelationSectionState();
}

class _BookmarkRelationSectionState extends State<BookmarkRelationSection> {
  late BacklinkRepository backlinks;
  late BookmarkObjectDetailContext _objectContext;
  late Future<int?> _bookmarkObjectId;

  BookmarkRepository get repository => widget.repository;
  BookmarkItem get bookmark => widget.bookmark;

  @override
  void initState() {
    super.initState();
    _bindRepository();
    _bookmarkObjectId = _resolveBookmarkObjectId();
  }

  @override
  void didUpdateWidget(covariant BookmarkRelationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _bindRepository();
    }
    if (oldWidget.repository != widget.repository ||
        oldWidget.bookmark.id != widget.bookmark.id) {
      _bookmarkObjectId = _resolveBookmarkObjectId();
    }
  }

  void _bindRepository() {
    backlinks = BacklinkRepository(repository);
    _objectContext = BookmarkObjectDetailContext.fromRepository(repository);
  }

  Future<int?> _resolveBookmarkObjectId() =>
      _objectContext.objectIdForBookmark(
        workspaceId: repository.workspaceId,
        bookmarkId: bookmark.id,
      );

  Future<void> _openObject(int objectId) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ObjectInspectorPage(
          store: _objectContext.store,
          objectStore: _objectContext.objectStore,
          objectId: objectId,
        ),
      ),
    );
  }

  Future<void> _addRelation(BuildContext context) async {
    final all = (await repository.watchAll().first)
        .where((item) => item.id != bookmark.id)
        .toList();
    if (!context.mounted) return;

    BookmarkItem? selected;
    var type = 'related';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('関連ブックマークを追加'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<BookmarkItem>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'ブックマーク'),
                  items: all
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.title, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocalState(() => selected = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Relation'),
                  items: _relationLabels.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setLocalState(() => type = value ?? 'related'),
                ),
              ],
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
                      await backlinks.link(
                        bookmark,
                        selected!,
                        relationType: type,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlink(BacklinkEntry entry) {
    if (entry.direction == BacklinkDirection.outgoing) {
      return backlinks.unlink(
        bookmark,
        entry.bookmark,
        relationType: entry.relationType,
      );
    }
    return backlinks.unlink(
      entry.bookmark,
      bookmark,
      relationType: entry.relationType,
    );
  }

  Widget _legacyRelations(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '関連ブックマーク',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '関連を追加',
              onPressed: () => _addRelation(context),
              icon: const Icon(Icons.add_link, size: 19),
            ),
          ],
        ),
        StreamBuilder<List<BacklinkEntry>>(
          stream: backlinks.watchFor(bookmark.id),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const <BacklinkEntry>[];
            if (entries.isEmpty) {
              return Text(
                '関連ブックマークはありません',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: entries.map((entry) {
                final outgoing = entry.direction == BacklinkDirection.outgoing;
                final relationLabel =
                    _relationLabels[entry.relationType] ?? entry.relationType;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    outgoing ? Icons.arrow_forward : Icons.arrow_back,
                    size: 17,
                  ),
                  title: Text(
                    entry.bookmark.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${entry.directionLabel} · $relationLabel'),
                  trailing: IconButton(
                    tooltip: '関連を解除',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _unlink(entry),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _universalBody(ColorScheme scheme) {
    return FutureBuilder<int?>(
      future: _bookmarkObjectId,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 36,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        }
        final objectId = snapshot.data;
        if (objectId == null) {
          // Older installations may not have completed Bookmark -> Object
          // mirroring. This read-only detail path must not manufacture identity.
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 18),
            ObjectBodyEditorSection(
              key: ValueKey('bookmark-object-body-${bookmark.id}'),
              store: _objectContext.store,
              objectStore: _objectContext.objectStore,
              objectId: objectId,
              workspaceId: repository.workspaceId,
              onOpenObject: (targetId) => _openObject(targetId),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legacyRelations(scheme),
        _universalBody(scheme),
      ],
    );
  }
}
