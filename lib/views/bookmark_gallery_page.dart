import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';

class BookmarkGalleryPage extends StatelessWidget {
  const BookmarkGalleryPage({
    super.key,
    required this.repository,
  });

  final BookmarkRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await repository.create(
            url: 'https://example.com',
            title: 'Example bookmark',
            description: 'Sample bookmark',
          );
        },
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
              child: Text('No bookmarks yet'),
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
              alignment: Alignment.center,
              child: bookmark.thumbnail == null
                  ? const Icon(Icons.image_outlined, size: 48)
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        bookmark.thumbnail!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
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
