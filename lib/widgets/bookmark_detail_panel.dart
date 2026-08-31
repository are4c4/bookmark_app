import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import 'photo_database_picker.dart';
import 'relation_database_picker.dart';

class BookmarkDetailPanel extends StatefulWidget {
  const BookmarkDetailPanel({
    super.key,
    required this.repository,
    required this.bookmark,
    required this.onClose,
    this.onFilterByTag,
    this.onFilterByPerson,
    this.onFilterByPhoto,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final VoidCallback onClose;
  final ValueChanged<Tag>? onFilterByTag;
  final ValueChanged<Person>? onFilterByPerson;
  final ValueChanged<PhotoRecord>? onFilterByPhoto;

  @override
  State<BookmarkDetailPanel> createState() => _BookmarkDetailPanelState();
}

class _BookmarkDetailPanelState extends State<BookmarkDetailPanel> {
  List<String> _split(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
    }
  }

  Future<void> _selectTagsFromDatabase() async {
    final allTags = await widget.repository.watchTags().first;
    if (!mounted) return;
    final selected = await showTagDatabasePicker(
      context: context,
      tags: allTags,
      initiallySelectedIds: widget.bookmark.tags.map((tag) => tag.id),
    );
    if (selected != null) await widget.repository.setBookmarkTagsFromDatabase(widget.bookmark, selected);
  }

  Future<void> _selectPeopleFromDatabase() async {
    final allPeople = await widget.repository.watchPeople().first;
    if (!mounted) return;
    final selected = await showPeopleDatabasePicker(
      context: context,
      people: allPeople,
      initiallySelectedIds: widget.bookmark.people.map((person) => person.id),
    );
    if (selected != null) await widget.repository.setBookmarkPeopleFromDatabase(widget.bookmark, selected);
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
    if (result != null) {
      await widget.repository.attachPhotos(widget.bookmark, result.photos, coverPhoto: result.coverPhoto);
    }
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
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(width: 240, height: 135, child: Image.file(File(selectedCover!.path), fit: BoxFit.cover)),
                    )
                  else
                    Text('ローカルのカバー画像は設定されていません', style: Theme.of(context).textTheme.bodySmall),
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
                await widget.repository.attachPhotos(bookmark, selectedPhotos, coverPhoto: clearCover ? null : selectedCover);
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
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }
    if (bookmark.thumbnail?.trim().isNotEmpty == true) {
      return Image.network(
        bookmark.thumbnail!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverPlaceholder(),
      );
    }
    return _coverPlaceholder();
  }

  Widget _coverPlaceholder() => Container(
        color: const Color(0xFFFAFAF9),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 40, color: Color(0xFFB8B7B4)),
      );

  Widget _propertyRow({
    required IconData icon,
    required String label,
    required Widget value,
    VoidCallback? onAdd,
    String? tooltip,
  }) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF9B9A97)),
                  const SizedBox(width: 7),
                  Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF787774))),
                ],
              ),
            ),
            Expanded(child: value),
            if (onAdd != null)
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: tooltip,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 17, color: Color(0xFF787774)),
                ),
              ),
          ],
        ),
      );

  Widget _relationChip({required String label, IconData? icon, required VoidCallback onPressed}) => ActionChip(
        avatar: icon == null ? null : Icon(icon, size: 14, color: const Color(0xFF787774)),
        label: Text(label),
        onPressed: onPressed,
        backgroundColor: const Color(0xFFF1F1EF),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF565653)),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
      );

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Row(
                children: [
                  const Text('詳細', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF787774))),
                  const Spacer(),
                  IconButton(
                    tooltip: '編集',
                    visualDensity: VisualDensity.compact,
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: bookmark.favorite ? 'お気に入り解除' : 'お気に入り',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.repository.toggleFavorite(bookmark),
                    icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border, size: 19),
                  ),
                  IconButton(
                    tooltip: '閉じる',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE7E7E4)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: _cover()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookmark.title,
                          style: const TextStyle(
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF37352F),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Tooltip(
                                message: bookmark.url,
                                child: Text(
                                  _compactUrl(bookmark.url),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF9B9A97)),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _openUrl(bookmark.url),
                              icon: const Icon(Icons.open_in_new, size: 15),
                              label: const Text('開く'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF565653),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _propertyRow(
                          icon: Icons.sell_outlined,
                          label: 'タグ',
                          value: bookmark.tags.isEmpty
                              ? const Text('なし', style: TextStyle(fontSize: 12.5, color: Color(0xFFB0AFAC)))
                              : Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: bookmark.tags
                                      .map((tag) => _relationChip(
                                            label: tag.name,
                                            onPressed: () => widget.onFilterByTag?.call(tag),
                                          ))
                                      .toList(),
                                ),
                          onAdd: _selectTagsFromDatabase,
                          tooltip: 'タグDBから選択',
                        ),
                        _propertyRow(
                          icon: Icons.people_outline,
                          label: '出演者',
                          value: bookmark.people.isEmpty
                              ? const Text('なし', style: TextStyle(fontSize: 12.5, color: Color(0xFFB0AFAC)))
                              : Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: bookmark.people
                                      .map((person) => _relationChip(
                                            label: person.name,
                                            icon: Icons.person_outline,
                                            onPressed: () => widget.onFilterByPerson?.call(person),
                                          ))
                                      .toList(),
                                ),
                          onAdd: _selectPeopleFromDatabase,
                          tooltip: '出演者DBから選択',
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1, color: Color(0xFFEDEDEB)),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Text('関連写真', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
                            const Spacer(),
                            IconButton(
                              tooltip: '写真DBから追加',
                              visualDensity: VisualDensity.compact,
                              onPressed: _addPhotosFromDatabase,
                              icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
                            ),
                            if (bookmark.coverPhoto != null)
                              IconButton(
                                tooltip: 'カバー解除',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => widget.repository.clearCoverPhoto(bookmark),
                                icon: const Icon(Icons.hide_image_outlined, size: 19),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (bookmark.photos.isEmpty)
                          const Text('関連写真はありません', style: TextStyle(fontSize: 12.5, color: Color(0xFF9B9A97)))
                        else
                          SizedBox(
                            height: 104,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: bookmark.photos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final photo = bookmark.photos[index];
                                final isCover = bookmark.coverPhoto?.id == photo.id;
                                return SizedBox(
                                  width: 126,
                                  child: Material(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      side: const BorderSide(color: Color(0xFFE7E7E4)),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => widget.onFilterByPhoto?.call(photo),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Image.file(File(photo.path), fit: BoxFit.cover),
                                                if (isCover)
                                                  const Positioned(
                                                    top: 5,
                                                    left: 5,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(3))),
                                                      child: Padding(
                                                        padding: EdgeInsets.all(3),
                                                        child: Icon(Icons.photo_size_select_actual, size: 13),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            height: 30,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 7),
                                                    child: Text(
                                                      photo.title ?? '写真',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF565653)),
                                                    ),
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  padding: EdgeInsets.zero,
                                                  iconSize: 17,
                                                  onSelected: (value) async {
                                                    if (value == 'filter') widget.onFilterByPhoto?.call(photo);
                                                    if (value == 'cover') await widget.repository.setCoverPhoto(bookmark, photo);
                                                    if (value == 'clear') await widget.repository.clearCoverPhoto(bookmark);
                                                    if (value == 'detach') await widget.repository.detachPhoto(bookmark, photo);
                                                  },
                                                  itemBuilder: (_) => [
                                                    const PopupMenuItem(value: 'filter', child: Text('この写真で絞り込む')),
                                                    if (!isCover) const PopupMenuItem(value: 'cover', child: Text('カバーにする')),
                                                    if (isCover) const PopupMenuItem(value: 'clear', child: Text('カバー解除')),
                                                    const PopupMenuDivider(),
                                                    const PopupMenuItem(value: 'detach', child: Text('関連を解除')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 22),
                        const Divider(height: 1, color: Color(0xFFEDEDEB)),
                        const SizedBox(height: 18),
                        const Text('説明', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
                        const SizedBox(height: 8),
                        Text(
                          bookmark.description?.trim().isNotEmpty == true ? bookmark.description! : '説明はありません。',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.55,
                            color: bookmark.description?.trim().isNotEmpty == true
                                ? const Color(0xFF565653)
                                : const Color(0xFF9B9A97),
                          ),
                        ),
                      ],
                    ),
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
