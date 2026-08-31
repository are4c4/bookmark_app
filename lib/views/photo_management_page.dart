import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/photo_storage_service.dart';
import '../widgets/photo_database_picker.dart';

class PhotoManagementPage extends StatelessWidget {
  const PhotoManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  List<String> _split(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _import(BuildContext context) async {
    try {
      final imported = await const PhotoStorageService().importImages();
      for (final photo in imported) {
        await repository.addPhoto(path: photo.path, title: photo.originalName);
      }
      if (!context.mounted) return;
      if (imported.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真は選択されませんでした')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imported.length} 枚の写真を追加しました')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('写真を追加できませんでした: $error'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _edit(BuildContext context, PhotoRecord photo) async {
    final title = TextEditingController(text: photo.title ?? '');
    final note = TextEditingController(text: photo.note ?? '');
    final tags = TextEditingController(text: photo.tags);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('写真を編集'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'タイトル')),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'メモ')),
              TextField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: '写真タグ（カンマ区切り）',
                  hintText: '風景, 夏, 資料',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              await repository.updatePhoto(
                photo,
                title: title.text.trim().isEmpty ? null : title.text.trim(),
                note: note.text.trim().isEmpty ? null : note.text.trim(),
                tagNames: _split(tags.text),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    title.dispose();
    note.dispose();
    tags.dispose();
  }

  Future<void> _attach(BuildContext context, PhotoRecord photo) async {
    final bookmarks = await repository.watchAll().first;
    if (!context.mounted) return;
    if (bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ブックマークがありません')));
      return;
    }

    BookmarkItem? selected = bookmarks.first;
    var asCover = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('ブックマークに写真を追加'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selected?.id,
                  decoration: const InputDecoration(labelText: 'ブックマーク'),
                  items: bookmarks
                      .map((bookmark) => DropdownMenuItem(value: bookmark.id, child: Text(bookmark.title)))
                      .toList(),
                  onChanged: (id) => setLocalState(() {
                    selected = bookmarks.where((b) => b.id == id).firstOrNull;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: asCover,
                  title: const Text('カバー（サムネイル）にする'),
                  onChanged: (value) => setLocalState(() => asCover = value),
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
                      await repository.attachPhoto(selected!, photo, asCover: asCover);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, PhotoRecord photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('写真を削除しますか？'),
        content: const Text('データベースから写真を削除します。ブックマークとの関連も解除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed == true) await repository.deletePhoto(photo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('写真')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _import(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('写真を追加'),
      ),
      body: StreamBuilder<List<PhotoRecord>>(
        stream: repository.watchPhotos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final photos = snapshot.data!;
          if (photos.isEmpty) {
            return const Center(child: Text('写真がありません。右下から追加できます。'));
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 270,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final tags = photoTagNames(photo);
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: Image.file(
                          File(photo.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 44)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 2),
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
                            onSelected: (value) {
                              if (value == 'attach') _attach(context, photo);
                              if (value == 'edit') _edit(context, photo);
                              if (value == 'delete') _delete(context, photo);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'attach', child: Text('ブックマークに追加')),
                              PopupMenuItem(value: 'edit', child: Text('編集・タグ')),
                              PopupMenuItem(value: 'delete', child: Text('削除')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: tags
                              .take(4)
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
