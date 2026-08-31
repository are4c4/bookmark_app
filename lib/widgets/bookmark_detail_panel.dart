import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import 'bookmark_custom_properties.dart';
import 'photo_database_picker.dart';

class BookmarkDetailPanel extends StatefulWidget {
  const BookmarkDetailPanel({
    super.key,
    required this.repository,
    required this.bookmark,
    required this.onClose,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final VoidCallback onClose;

  @override
  State<BookmarkDetailPanel> createState() => _BookmarkDetailPanelState();
}

class _BookmarkDetailPanelState extends State<BookmarkDetailPanel> {
  List<String> _split(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URLを開けませんでした')),
      );
    }
  }

  Future<void> _addPhotosFromDatabase() async {
    final allPhotos = await widget.repository.watchPhotos().first;
    if (!mounted) return;
    final result = await showPhotoDatabasePicker(
      context: context,
      photos: allPhotos,
      initiallySelectedIds: widget.bookmark.photos.map((photo) => photo.id),
      initialCoverPhotoId: widget.bookmark.coverPhoto?.id,
      title: '関連写真を選択',
    );
    if (result == null) return;
    await widget.repository.attachPhotos(
      widget.bookmark,
      result.photos,
      coverPhoto: result.coverPhoto,
    );
  }

  Future<void> _edit() async {
    final bookmark = widget.bookmark;
    final title = TextEditingController(text: bookmark.title);
    final url = TextEditingController(text: bookmark.url);
    final description = TextEditingController(text: bookmark.description ?? '');
    final thumbnail = TextEditingController(text: bookmark.thumbnail ?? '');
    final tags = TextEditingController(text: bookmark.tags.map((e) => e.name).join(', '));
    final people = TextEditingController(text: bookmark.people.map((e) => e.name).join(', '));
    var selectedPhotos = <PhotoRecord>[...bookmark.photos];
    PhotoRecord? selectedCover = bookmark.coverPhoto;
    var clearCover = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('詳細を編集'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'タイトル')),
                  TextField(controller: url, decoration: const InputDecoration(labelText: 'URL')),
                  TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: '説明')),
                  TextField(controller: thumbnail, decoration: const InputDecoration(labelText: 'WebサムネイルURL')),
                  TextField(controller: tags, decoration: const InputDecoration(labelText: 'タグ（カンマ区切り）')),
                  TextField(controller: people, decoration: const InputDecoration(labelText: '出演者（カンマ区切り）')),
                  const SizedBox(height: 20),
                  Text('カバー画像', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (!clearCover && selectedCover != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 220,
                        height: 130,
                        child: Image.file(
                          File(selectedCover!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                        ),
                      ),
                    )
                  else
                    Text(
                      'ローカルのカバー画像は設定されていません',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final allPhotos = await widget.repository.watchPhotos().first;
                          if (!context.mounted) return;
                          final result = await showPhotoDatabasePicker(
                            context: context,
                            photos: allPhotos,
                            initiallySelectedIds: selectedPhotos.map((photo) => photo.id),
                            initialCoverPhotoId: clearCover ? null : selectedCover?.id,
                            title: 'サムネイル・関連写真を選択',
                          );
                          if (result == null) return;
                          setLocalState(() {
                            selectedPhotos = result.photos;
                            selectedCover = result.coverPhoto;
                            clearCover = false;
                          });
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('写真DBから選択'),
                      ),
                      if (bookmark.coverPhoto != null || selectedCover != null)
                        OutlinedButton.icon(
                          onPressed: () => setLocalState(() {
                            clearCover = true;
                            selectedCover = null;
                          }),
                          icon: const Icon(Icons.hide_image_outlined),
                          label: const Text('カバーを解除'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.repository.update(
                  id: bookmark.id,
                  url: url.text.trim(),
                  title: title.text.trim(),
                  description: description.text.trim().isEmpty ? null : description.text.trim(),
                  thumbnail: thumbnail.text.trim().isEmpty ? null : thumbnail.text.trim(),
                  tagNames: _split(tags.text),
                  personNames: _split(people.text),
                );
                await widget.repository.attachPhotos(
                  bookmark,
                  selectedPhotos,
                  coverPhoto: clearCover ? null : selectedCover,
                );
                if (clearCover) await widget.repository.clearCoverPhoto(bookmark);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    url.dispose();
    description.dispose();
    thumbnail.dispose();
    tags.dispose();
    people.dispose();
  }

  Widget _cover() {
    final bookmark = widget.bookmark;
    if (bookmark.coverPhoto != null) {
      return Image.file(
        File(bookmark.coverPhoto!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 42)),
      );
    }
    if (bookmark.thumbnail?.trim().isNotEmpty == true) {
      return Image.network(
        bookmark.thumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 42)),
      );
    }
    return const Center(child: Icon(Icons.image_outlined, size: 42));
  }

  Widget _property(String label, Widget value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: value),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                const Text('詳細', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  tooltip: '閉じる',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(aspectRatio: 16 / 9, child: _cover()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bookmark.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'お気に入り',
                        onPressed: () => widget.repository.toggleFavorite(bookmark),
                        icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                      ),
                      IconButton(
                        tooltip: '編集',
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: SelectableText(bookmark.url, maxLines: 2)),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _openUrl(bookmark.url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('開く'),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _property(
                    'タグ',
                    bookmark.tags.isEmpty
                        ? const Text('なし')
                        : Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: bookmark.tags.map((t) => Chip(label: Text(t.name))).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _property(
                    '出演者',
                    bookmark.people.isEmpty
                        ? const Text('なし')
                        : Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: bookmark.people.map((p) => Chip(label: Text(p.name))).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text('カスタム項目', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  BookmarkCustomProperties(
                    repository: widget.repository,
                    bookmarkId: bookmark.id,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('関連写真', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      IconButton(
                        tooltip: '写真DBから追加',
                        onPressed: _addPhotosFromDatabase,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      if (bookmark.coverPhoto != null)
                        IconButton(
                          tooltip: 'カバー解除',
                          onPressed: () => widget.repository.clearCoverPhoto(bookmark),
                          icon: const Icon(Icons.hide_image_outlined),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (bookmark.photos.isEmpty)
                    const Text('関連写真はありません')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bookmark.photos.map((photo) {
                        final isCover = bookmark.coverPhoto?.id == photo.id;
                        return SizedBox(
                          width: 130,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        File(photo.path),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                                      ),
                                      if (isCover)
                                        const Positioned(
                                          top: 4,
                                          left: 4,
                                          child: Icon(Icons.photo_size_select_actual, size: 18),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Text(
                                          photo.title ?? '写真',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'cover') await widget.repository.setCoverPhoto(bookmark, photo);
                                        if (value == 'clear') await widget.repository.clearCoverPhoto(bookmark);
                                        if (value == 'detach') await widget.repository.detachPhoto(bookmark, photo);
                                      },
                                      itemBuilder: (_) => [
                                        if (!isCover)
                                          const PopupMenuItem(value: 'cover', child: Text('カバーにする')),
                                        if (isCover)
                                          const PopupMenuItem(value: 'clear', child: Text('カバー解除')),
                                        const PopupMenuItem(value: 'detach', child: Text('関連を解除')),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  Text('説明', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    bookmark.description?.trim().isNotEmpty == true
                        ? bookmark.description!
                        : '説明はありません。',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
