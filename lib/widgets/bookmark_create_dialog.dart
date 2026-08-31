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

Future<void> showBookmarkCreateDialog({
  required BuildContext context,
  required BookmarkRepository repository,
}) async {
  final url = TextEditingController();
  final tags = TextEditingController();
  var selectedPhotos = <PhotoRecord>[];
  PhotoRecord? coverPhoto;
  var saving = false;

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

        Future<void> save() async {
          if (saving || url.text.trim().isEmpty) return;
          setLocalState(() => saving = true);
          try {
            final metadata = await const BookmarkMetadataService().fetch(url.text.trim());
            final bookmarkId = await repository.create(
              url: metadata.url,
              title: metadata.title,
              thumbnail: metadata.thumbnail,
              description: metadata.description,
              tagNames: _splitNames(tags.text),
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
            width: 560,
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
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
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
