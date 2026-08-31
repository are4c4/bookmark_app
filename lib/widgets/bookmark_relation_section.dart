import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../repositories/backlink_repository.dart';

const _relationLabels = <String, String>{
  'related': '関連',
  'sequel': '続編',
  'previous': '前編',
  'reference': '参考',
  'source': '元記事 / 元動画',
};

class BookmarkRelationSection extends StatelessWidget {
  BookmarkRelationSection({
    super.key,
    required this.repository,
    required this.bookmark,
  }) : backlinks = BacklinkRepository(repository);

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final BacklinkRepository backlinks;

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
                      .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: (value) => setLocalState(() => type = value ?? 'related'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await backlinks.link(bookmark, selected!, relationType: type);
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              );
            }
            return Column(
              children: entries.map((entry) {
                final outgoing = entry.direction == BacklinkDirection.outgoing;
                final relationLabel = _relationLabels[entry.relationType] ?? entry.relationType;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(outgoing ? Icons.arrow_forward : Icons.arrow_back, size: 17),
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
}
