import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_metadata_service.dart';
import 'photo_database_picker.dart';

List<String> _splitNames(String value) => value
    .split(',')
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toList();

const _statusLabels = <String, String>{
  'unread': '未読',
  'later': '後で見る',
  'in_progress': '閲覧中 / 視聴中',
  'done': '完了 / 視聴済み',
  'archived': 'アーカイブ',
};

Future<void> showBookmarkCreateDialog({
  required BuildContext context,
  required BookmarkRepository repository,
  bool initialInbox = false,
}) async {
  final url = TextEditingController();
  final tags = TextEditingController();
  var selectedPhotos = <PhotoRecord>[];
  PhotoRecord? coverPhoto;
  var saving = false;
  var status = 'unread';
  var rating = 0;
  var inbox = initialInbox;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        Future<void> choosePhotos() async {
          final photos = await repository.watchPhotos().first;
          if (!context.mounted) return;
          final result = await showPhotoDatabasePicker(
            context: context,
            photos: photos,
            initiallySelectedIds: selectedPhotos.map((photo) => photo.id),
            initialCoverPhotoId: coverPhoto?.id,
            title: 'ブックマークに追加する写真',
          );
          if (result == null) return;
          setLocalState(() {
            selectedPhotos = result.photos;
            coverPhoto = result.coverPhoto;
          });
        }

        Future<bool> confirmDuplicate(BookmarkItem duplicate) async {
          final choice = await showDialog<String>(
            context: context,
            builder: (duplicateContext) => AlertDialog(
              title: const Text('同じURLが登録されています'),
              content: Text('「${duplicate.title}」がすでに存在します。\nそれでも新しく追加しますか？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(duplicateContext, 'cancel'),
                  child: const Text('キャンセル'),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(duplicateContext, 'add'),
                  child: const Text('それでも追加'),
                ),
              ],
            ),
          );
          return choice == 'add';
        }

        Future<void> save() async {
          if (saving || url.text.trim().isEmpty) return;
          setLocalState(() => saving = true);
          try {
            final duplicate = await repository.findDuplicateUrl(url.text.trim());
            if (duplicate != null) {
              final proceed = await confirmDuplicate(duplicate);
              if (!proceed) {
                setLocalState(() => saving = false);
                return;
              }
            }

            final metadata = await const BookmarkMetadataService().fetch(url.text.trim());
            final bookmarkId = await repository.create(
              url: metadata.url,
              title: metadata.title,
              thumbnail: metadata.thumbnail,
              description: metadata.description,
              tagNames: _splitNames(tags.text),
              status: status,
              rating: rating,
              inbox: inbox,
            );
            if (selectedPhotos.isNotEmpty) {
              await repository.attachPhotosByBookmarkId(
                bookmarkId,
                selectedPhotos,
                coverPhoto: coverPhoto,
              );
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          } catch (error) {
            setLocalState(() => saving = false);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ブックマークを追加できませんでした: $error')),
              );
            }
          }
        }

        return AlertDialog(
          title: const Text('ブックマークを追加'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: url,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => save(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'タグ（カンマ区切り）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Inboxに入れる'),
                    subtitle: const Text('後でタグや人物などを整理するための一時保存'),
                    value: inbox,
                    onChanged: (value) => setLocalState(() => inbox = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'ステータス', border: OutlineInputBorder()),
                          items: _statusLabels.entries
                              .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                              .toList(),
                          onChanged: (value) => setLocalState(() => status = value ?? 'unread'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: rating,
                          decoration: const InputDecoration(labelText: '評価', border: OutlineInputBorder()),
                          items: List.generate(6, (index) => DropdownMenuItem(
                                value: index,
                                child: Text(index == 0 ? '未評価' : '${'★' * index}${'☆' * (5 - index)}'),
                              )),
                          onChanged: (value) => setLocalState(() => rating = value ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: saving ? null : choosePhotos,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('写真DBから選択'),
                      ),
                      const SizedBox(width: 10),
                      Text('${selectedPhotos.length}枚選択'),
                    ],
                  ),
                  if (coverPhoto != null) ...[
                    const SizedBox(height: 12),
                    Text('カバー画像', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 220,
                        height: 130,
                        child: Image.file(
                          File(coverPhoto!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
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
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? '取得中…' : '追加'),
            ),
          ],
        );
      },
    ),
  );

  url.dispose();
  tags.dispose();
}
