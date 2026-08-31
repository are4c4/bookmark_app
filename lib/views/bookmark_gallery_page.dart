import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_metadata_service.dart';

class BookmarkGalleryPage extends StatelessWidget {
  const BookmarkGalleryPage({
    super.key,
    required this.repository,
  });

  final BookmarkRepository repository;

  Future<void> _showAddBookmarkDialog(BuildContext context) async {
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSaving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> save() async {
              if (isSaving || !(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setState(() {
                isSaving = true;
                errorText = null;
              });

              try {
                final metadata = const BookmarkMetadataService().fetch(
                  urlController.text,
                );
                final result = await metadata;

                await repository.create(
                  url: result.url,
                  title: result.title,
                  thumbnail: result.thumbnail,
                  description: result.description,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (error) {
                setState(() {
                  isSaving = false;
                  errorText = '保存できませんでした。URLを確認してください。';
                });
              }
            }

            return AlertDialog(
              title: const Text('ブックマークを追加'),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'URLを入力すると、タイトルとサムネイルを自動取得します。',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: urlController,
                        autofocus: true,
                        enabled: !isSaving,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          hintText: 'https://example.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final input = value?.trim() ?? '';
                          if (input.isEmpty) {
                            return 'URLを入力してください';
                          }

                          final normalized = input.startsWith('http://') ||
                                  input.startsWith('https://')
                              ? input
                              : 'https://$input';
                          final uri = Uri.tryParse(normalized);
                          if (uri == null || uri.host.isEmpty) {
                            return '有効なURLを入力してください';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => save(),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton.icon(
                  onPressed: isSaving ? null : save,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_link),
                  label: Text(isSaving ? '取得中…' : '追加'),
                ),
              ],
            );
          },
        );
      },
    );

    urlController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBookmarkDialog(context),
        tooltip: 'ブックマークを追加',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Bookmark>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookmarks = snapshot.data ?? const <Bookmark>[];

          if (bookmarks.isEmpty) {
            return const Center(
              child: Text('右下の＋からブックマークを追加できます'),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 1100
                  ? 5
                  : width >= 800
                      ? 4
                      : width >= 600
                          ? 3
                          : 2;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index];
                  return _BookmarkCard(
                    bookmark: bookmark,
                    onFavoritePressed: () => repository.toggleFavorite(bookmark),
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

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.bookmark,
    required this.onFavoritePressed,
  });

  final Bookmark bookmark;
  final VoidCallback onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: bookmark.thumbnail == null
                  ? const Center(
                      child: Icon(Icons.image_outlined, size: 48),
                    )
                  : Image.network(
                      bookmark.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookmark.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bookmark.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Favorite',
                  onPressed: onFavoritePressed,
                  icon: Icon(
                    bookmark.favorite ? Icons.star : Icons.star_border,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
