import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../widgets/photo_database_picker.dart';

class BookmarkDetailsPage extends StatefulWidget {
  const BookmarkDetailsPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<BookmarkDetailsPage> createState() => _BookmarkDetailsPageState();
}

class _BookmarkDetailsPageState extends State<BookmarkDetailsPage> {
  int? _selectedId;

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

  Future<PhotoPickerResult?> _pickPhotos(
    BookmarkItem bookmark, {
    String title = '写真DBから選択',
  }) async {
    final allPhotos = await widget.repository.watchPhotos().first;
    if (!mounted) return null;
    return showPhotoDatabasePicker(
      context: context,
      photos: allPhotos,
      initiallySelectedIds: bookmark.photos.map((photo) => photo.id),
      initialCoverPhotoId: bookmark.coverPhoto?.id,
      title: title,
    );
  }

  Future<void> _addPhotosFromDatabase(BookmarkItem bookmark) async {
    final result = await _pickPhotos(bookmark, title: '関連写真を選択');
    if (result == null) return;
    await widget.repository.attachPhotos(
      bookmark,
      result.photos,
      coverPhoto: result.coverPhoto,
    );
  }

  Future<void> _edit(BookmarkItem bookmark) async {
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
                  TextField(
                    controller: people,
                    decoration: const InputDecoration(
                      labelText: '出演者（カンマ区切り）',
                      hintText: '出演者A, 出演者B',
                    ),
                  ),
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
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('写真DBから選択'),
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
                      ),
                      if ((!clearCover && selectedCover != null) || bookmark.coverPhoto != null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.hide_image_outlined),
                          label: const Text('カバーを解除'),
                          onPressed: () => setLocalState(() {
                            clearCover = true;
                            selectedCover = null;
                          }),
                        ),
                    ],
                  ),
                  if (selectedPhotos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('関連写真: ${selectedPhotos.length}枚', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
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

  Widget _cover(BookmarkItem bookmark) {
    if (bookmark.coverPhoto != null) {
      return Image.file(
        File(bookmark.coverPhoto!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
      );
    }
    if (bookmark.thumbnail != null) {
      return Image.network(
        bookmark.thumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
      );
    }
    return const Center(child: Icon(Icons.image_outlined, size: 48));
  }

  Widget _photoSection(BookmarkItem bookmark) {
    if (bookmark.photos.isEmpty) {
      return const Text('関連写真はありません。「写真DBから追加」で選択できます。');
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: bookmark.photos.map((photo) {
        final isCover = bookmark.coverPhoto?.id == photo.id;
        return SizedBox(
          width: 190,
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
                          top: 6,
                          left: 6,
                          child: Chip(
                            avatar: Icon(Icons.photo_size_select_actual, size: 15),
                            label: Text('カバー'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          photo.title?.trim().isNotEmpty == true ? photo.title! : '写真 ${photo.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'cover') await widget.repository.setCoverPhoto(bookmark, photo);
                          if (value == 'clearCover') await widget.repository.clearCoverPhoto(bookmark);
                          if (value == 'detach') await widget.repository.detachPhoto(bookmark, photo);
                        },
                        itemBuilder: (_) => [
                          if (!isCover) const PopupMenuItem(value: 'cover', child: Text('カバーにする')),
                          if (isCover) const PopupMenuItem(value: 'clearCover', child: Text('カバーを解除')),
                          const PopupMenuItem(value: 'detach', child: Text('関連を解除')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _detail(BookmarkItem bookmark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(aspectRatio: 16 / 9, child: _cover(bookmark)),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(bookmark.title, style: Theme.of(context).textTheme.headlineMedium)),
                  IconButton(
                    tooltip: 'お気に入り',
                    onPressed: () => widget.repository.toggleFavorite(bookmark),
                    icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _edit(bookmark),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('編集'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: SelectableText(bookmark.url)),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _openUrl(bookmark.url),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('開く'),
                  ),
                ],
              ),
              const Divider(height: 36),
              _property(
                'タグ',
                bookmark.tags.isEmpty
                    ? const Text('なし')
                    : Wrap(spacing: 6, runSpacing: 6, children: bookmark.tags.map((tag) => Chip(label: Text(tag.name))).toList()),
              ),
              const SizedBox(height: 20),
              _property(
                '出演者',
                bookmark.people.isEmpty
                    ? const Text('なし')
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: bookmark.people
                            .map((person) => Chip(avatar: const Icon(Icons.person_outline, size: 17), label: Text(person.name)))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 20),
              _property('登録日時', Text(bookmark.createdAt.toLocal().toString())),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text('関連写真', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _addPhotosFromDatabase(bookmark),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('写真DBから追加'),
                  ),
                  if (bookmark.coverPhoto != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => widget.repository.clearCoverPhoto(bookmark),
                      icon: const Icon(Icons.hide_image_outlined),
                      label: const Text('カバー解除'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _photoSection(bookmark),
              const SizedBox(height: 28),
              Text('説明', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                bookmark.description?.trim().isNotEmpty == true ? bookmark.description! : '説明はありません。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _property(String label, Widget value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: value),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('詳細')),
      body: StreamBuilder<List<BookmarkItem>>(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final bookmarks = snapshot.data!;
          if (bookmarks.isEmpty) return const Center(child: Text('ブックマークがありません'));

          final selected = bookmarks.where((b) => b.id == _selectedId).firstOrNull ?? bookmarks.first;
          _selectedId ??= selected.id;

          return Row(
            children: [
              SizedBox(
                width: 300,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = bookmarks[index];
                    return ListTile(
                      selected: bookmark.id == selected.id,
                      leading: SizedBox(
                        width: 44,
                        height: 34,
                        child: ClipRRect(borderRadius: BorderRadius.circular(4), child: _cover(bookmark)),
                      ),
                      title: Text(bookmark.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: bookmark.people.isEmpty
                          ? null
                          : Text(bookmark.people.map((e) => e.name).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => setState(() => _selectedId = bookmark.id),
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _detail(selected)),
            ],
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
