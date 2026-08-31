import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';

class PhotoPickerResult {
  const PhotoPickerResult({required this.photos, this.coverPhoto});

  final List<PhotoRecord> photos;
  final PhotoRecord? coverPhoto;
}

List<String> photoTagNames(PhotoRecord photo) => photo.tags
    .split(',')
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toList();

Future<PhotoPickerResult?> showPhotoDatabasePicker({
  required BuildContext context,
  required List<PhotoRecord> photos,
  Iterable<int> initiallySelectedIds = const [],
  int? initialCoverPhotoId,
  String title = '写真DBから選択',
}) async {
  if (photos.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('写真DBに写真がありません。「写真」画面から追加してください。')),
    );
    return null;
  }

  final selectedIds = initiallySelectedIds.toSet();
  var coverId = initialCoverPhotoId;
  var query = '';

  return showDialog<PhotoPickerResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final normalizedQuery = query.trim().toLowerCase();
        final visiblePhotos = photos.where((photo) {
          if (normalizedQuery.isEmpty) return true;
          final text = [
            photo.title ?? '',
            photo.note ?? '',
            photo.tags,
          ].join(' ').toLowerCase();
          return text.contains(normalizedQuery);
        }).toList();

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 760,
            height: 560,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '写真名・メモ・タグを検索',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setLocalState(() => query = value),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: visiblePhotos.length,
                    itemBuilder: (context, index) {
                      final photo = visiblePhotos[index];
                      final selected = selectedIds.contains(photo.id);
                      final isCover = coverId == photo.id;
                      final tags = photoTagNames(photo);

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setLocalState(() {
                            if (selected) {
                              selectedIds.remove(photo.id);
                              if (coverId == photo.id) coverId = null;
                            } else {
                              selectedIds.add(photo.id);
                            }
                          }),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      File(photo.path),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image_outlined, size: 40),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Material(
                                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                                        shape: const CircleBorder(),
                                        child: Checkbox(
                                          value: selected,
                                          onChanged: (_) => setLocalState(() {
                                            if (selected) {
                                              selectedIds.remove(photo.id);
                                              if (coverId == photo.id) coverId = null;
                                            } else {
                                              selectedIds.add(photo.id);
                                            }
                                          }),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                                child: Text(
                                  photo.title?.trim().isNotEmpty == true
                                      ? photo.title!
                                      : '写真 ${photo.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tags.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                                  child: Text(
                                    tags.join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              RadioListTile<int>(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                title: const Text('カバー', style: TextStyle(fontSize: 12)),
                                value: photo.id,
                                groupValue: coverId,
                                onChanged: selected
                                    ? (value) => setLocalState(() => coverId = value)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${selectedIds.length} 枚選択中'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () {
                      final selectedPhotos = photos
                          .where((photo) => selectedIds.contains(photo.id))
                          .toList();
                      final coverPhoto = coverId == null
                          ? null
                          : photos.where((photo) => photo.id == coverId).firstOrNull;
                      Navigator.pop(
                        dialogContext,
                        PhotoPickerResult(
                          photos: selectedPhotos,
                          coverPhoto: coverPhoto,
                        ),
                      );
                    },
              child: const Text('選択'),
            ),
          ],
        );
      },
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
