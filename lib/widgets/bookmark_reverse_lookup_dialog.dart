import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';

Future<void> showBookmarkReverseLookupDialog({
  required BuildContext context,
  required String title,
  required Stream<List<BookmarkItem>> bookmarks,
}) {
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
                      child: _BookmarkLookupThumbnail(bookmark: bookmark),
                    ),
                  ),
                  title: Text(
                    bookmark.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    bookmark.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'ブラウザで開く',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () async {
                      final uri = Uri.tryParse(bookmark.url);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
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

class _BookmarkLookupThumbnail extends StatelessWidget {
  const _BookmarkLookupThumbnail({required this.bookmark});

  final BookmarkItem bookmark;

  @override
  Widget build(BuildContext context) {
    if (bookmark.coverPhoto != null) {
      return Image.file(
        File(bookmark.coverPhoto!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _Placeholder(),
      );
    }
    if (bookmark.thumbnail?.trim().isNotEmpty == true) {
      return Image.network(
        bookmark.thumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _Placeholder(),
      );
    }
    return const _Placeholder();
  }
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
