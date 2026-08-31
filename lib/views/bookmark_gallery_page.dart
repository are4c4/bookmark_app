import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_metadata_service.dart';

enum BookmarkViewType { gallery, list, table }

class BookmarkGalleryPage extends StatefulWidget {
  const BookmarkGalleryPage({
    super.key,
    required this.repository,
  });

  final BookmarkRepository repository;

  @override
  State<BookmarkGalleryPage> createState() => _BookmarkGalleryPageState();
}

class _BookmarkGalleryPageState extends State<BookmarkGalleryPage> {
  final _searchController = TextEditingController();
  BookmarkViewType _viewType = BookmarkViewType.gallery;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _tagsOf(Bookmark bookmark) {
    return bookmark.tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  List<Bookmark> _filterBookmarks(List<Bookmark> bookmarks) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return bookmarks;

    return bookmarks.where((bookmark) {
      return bookmark.title.toLowerCase().contains(query) ||
          bookmark.url.toLowerCase().contains(query) ||
          (bookmark.description ?? '').toLowerCase().contains(query) ||
          bookmark.tags.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openBookmark(Bookmark bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URLを開けませんでした')),
      );
    }
  }

  Future<void> _showAddBookmarkDialog() async {
    final urlController = TextEditingController();
    final tagsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSaving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (isSaving || !(formKey.currentState?.validate() ?? false)) return;

              setDialogState(() {
                isSaving = true;
                errorText = null;
              });

              try {
                final result = await const BookmarkMetadataService().fetch(
                  urlController.text,
                );

                await widget.repository.create(
                  url: result.url,
                  title: result.title,
                  thumbnail: result.thumbnail,
                  description: result.description,
                  tags: tagsController.text.trim(),
                );

                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (_) {
                setDialogState(() {
                  isSaving = false;
                  errorText = '保存できませんでした。URLを確認してください。';
                });
              }
            }

            return AlertDialog(
              title: const Text('ブックマークを追加'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: urlController,
                        autofocus: true,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          hintText: 'https://example.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final input = value?.trim() ?? '';
                          if (input.isEmpty) return 'URLを入力してください';
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagsController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: 'タグ（カンマ区切り）',
                          hintText: 'AI, 開発, 後で読む',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
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
    tagsController.dispose();
  }

  Future<void> _showEditDialog(Bookmark bookmark) async {
    final titleController = TextEditingController(text: bookmark.title);
    final urlController = TextEditingController(text: bookmark.url);
    final descriptionController = TextEditingController(
      text: bookmark.description ?? '',
    );
    final thumbnailController = TextEditingController(
      text: bookmark.thumbnail ?? '',
    );
    final tagsController = TextEditingController(text: bookmark.tags);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ブックマークを編集'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'タイトル'),
                  ),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(labelText: 'URL'),
                  ),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '説明'),
                  ),
                  TextField(
                    controller: thumbnailController,
                    decoration: const InputDecoration(labelText: 'サムネイルURL'),
                  ),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'タグ（カンマ区切り）',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.repository.update(
                  id: bookmark.id,
                  url: urlController.text.trim(),
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  thumbnail: thumbnailController.text.trim().isEmpty
                      ? null
                      : thumbnailController.text.trim(),
                  tags: tagsController.text.trim(),
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    urlController.dispose();
    descriptionController.dispose();
    thumbnailController.dispose();
    tagsController.dispose();
  }

  Future<void> _confirmDelete(Bookmark bookmark) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「${bookmark.title}」を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (delete == true) await widget.repository.delete(bookmark.id);
  }

  Widget _actionsFor(Bookmark bookmark) {
    return PopupMenuButton<String>(
      tooltip: '操作',
      onSelected: (value) {
        if (value == 'open') _openBookmark(bookmark);
        if (value == 'edit') _showEditDialog(bookmark);
        if (value == 'delete') _confirmDelete(bookmark);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'open', child: Text('開く')),
        PopupMenuItem(value: 'edit', child: Text('編集')),
        PopupMenuItem(value: 'delete', child: Text('削除')),
      ],
    );
  }

  Widget _buildGallery(List<Bookmark> bookmarks) {
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
            childAspectRatio: 0.9,
          ),
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openBookmark(bookmark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: bookmark.thumbnail == null
                            ? const Center(
                                child: Icon(Icons.image_outlined, size: 48),
                              )
                            : Image.network(
                                bookmark.thumbnail!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 48,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bookmark.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              IconButton(
                                tooltip: 'お気に入り',
                                onPressed: () =>
                                    widget.repository.toggleFavorite(bookmark),
                                icon: Icon(
                                  bookmark.favorite
                                      ? Icons.star
                                      : Icons.star_border,
                                ),
                              ),
                              _actionsFor(bookmark),
                            ],
                          ),
                          Text(
                            bookmark.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (_tagsOf(bookmark).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: _tagsOf(bookmark)
                                  .take(3)
                                  .map((tag) => Chip(
                                        label: Text(tag),
                                        visualDensity: VisualDensity.compact,
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildList(List<Bookmark> bookmarks) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return ListTile(
          onTap: () => _openBookmark(bookmark),
          leading: SizedBox(
            width: 72,
            height: 52,
            child: bookmark.thumbnail == null
                ? const Icon(Icons.bookmark_border)
                : Image.network(
                    bookmark.thumbnail!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
          title: Text(bookmark.title),
          subtitle: Text(
            [bookmark.url, ..._tagsOf(bookmark)].join('  •  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => widget.repository.toggleFavorite(bookmark),
                icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
              ),
              _actionsFor(bookmark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTable(List<Bookmark> bookmarks) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('タイトル')),
            DataColumn(label: Text('URL')),
            DataColumn(label: Text('タグ')),
            DataColumn(label: Text('お気に入り')),
            DataColumn(label: Text('操作')),
          ],
          rows: bookmarks.map((bookmark) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Text(
                      bookmark.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onTap: () => _openBookmark(bookmark),
                ),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      bookmark.url,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onTap: () => _openBookmark(bookmark),
                ),
                DataCell(Text(_tagsOf(bookmark).join(', '))),
                DataCell(
                  IconButton(
                    onPressed: () => widget.repository.toggleFavorite(bookmark),
                    icon: Icon(
                      bookmark.favorite ? Icons.star : Icons.star_border,
                    ),
                  ),
                ),
                DataCell(_actionsFor(bookmark)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: '検索',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<BookmarkViewType>(
              value: _viewType,
              onChanged: (value) {
                if (value != null) setState(() => _viewType = value);
              },
              items: const [
                DropdownMenuItem(
                  value: BookmarkViewType.gallery,
                  child: Row(
                    children: [Icon(Icons.grid_view), SizedBox(width: 8), Text('Gallery')],
                  ),
                ),
                DropdownMenuItem(
                  value: BookmarkViewType.list,
                  child: Row(
                    children: [Icon(Icons.view_list), SizedBox(width: 8), Text('List')],
                  ),
                ),
                DropdownMenuItem(
                  value: BookmarkViewType.table,
                  child: Row(
                    children: [Icon(Icons.table_rows), SizedBox(width: 8), Text('Table')],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBookmarkDialog,
        tooltip: 'ブックマークを追加',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Bookmark>>(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookmarks = _filterBookmarks(
            snapshot.data ?? const <Bookmark>[],
          );

          if (bookmarks.isEmpty) {
            return Center(
              child: Text(
                _query.isEmpty
                    ? '右下の＋からブックマークを追加できます'
                    : '検索結果がありません',
              ),
            );
          }

          switch (_viewType) {
            case BookmarkViewType.gallery:
              return _buildGallery(bookmarks);
            case BookmarkViewType.list:
              return _buildList(bookmarks);
            case BookmarkViewType.table:
              return _buildTable(bookmarks);
          }
        },
      ),
    );
  }
}
