import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_url_resolver.dart';
import 'bookmark_visual_image.dart';

typedef BookmarkUrlResolve = Future<BookmarkUrlSource?> Function(
  BookmarkItem bookmark,
);

Future<void> showBookmarkReverseLookupDialog({
  required BuildContext context,
  required BookmarkRepository repository,
  required String title,
  required Stream<List<BookmarkItem>> bookmarks,
  BookmarkUrlResolve? resolveUrl,
}) {
  final resolver = resolveUrl ??
      BookmarkUrlResolver(
        database: repository.workspaceStore.database,
        workspaceId: repository.workspaceId,
      ).resolve;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 680,
        height: 480,
        child: StreamBuilder<List<BookmarkItem>>(
          stream: bookmarks,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(child: Text('関連するブックマークはありません。'));
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bookmark = items[index];
                return ListTile(
                  leading: SizedBox(
                    width: 72,
                    height: 48,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: BookmarkVisualImage(
                        repository: repository,
                        bookmark: bookmark,
                        width: 72,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: const _Placeholder(),
                      ),
                    ),
                  ),
                  title: Text(
                    bookmark.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: FutureBuilder<BookmarkUrlSource?>(
                    future: resolver(bookmark),
                    builder: (context, snapshot) => Text(
                      snapshot.data?.value ?? bookmark.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'ブラウザで開く',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () async {
                      final source = await resolver(bookmark);
                      if (source == null) return;
                      final uri = Uri.tryParse(source.value);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.bookmark_outline),
      );
}
