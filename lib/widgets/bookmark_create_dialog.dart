import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_attachment_store.dart';
import '../data/bookmark_repository.dart';
import '../services/attachment_storage_service.dart';
import '../services/bookmark_metadata_service.dart';
import '../services/pdf_metadata_service.dart';
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

String _fileTitle(String path) {
  final normalized = path.replaceAll('\\', '/');
  final name = normalized.substring(normalized.lastIndexOf('/') + 1);
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

void _debugAuthorCreationFailure(StackTrace stackTrace) {
  assert(() {
    debugPrint(
      'BookmarkCreateDialog: best-effort PDF author creation failed.',
    );
    debugPrintStack(stackTrace: stackTrace);
    return true;
  }());
}

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

        Future<void> createFromFiles() async {
          if (saving) return;
          final profilePath = repository.profileDirectoryPath;
          if (profilePath == null) return;
          setLocalState(() => saving = true);
          BookmarkAttachmentStore? store;
          try {
            const storage = AttachmentStorageService();
            final paths = await storage.pickFiles();
            if (paths.isEmpty) {
              setLocalState(() => saving = false);
              return;
            }
            store = BookmarkAttachmentStore(repository.lifecycleStore.database);
            await store.initialize();
            var createdCount = 0;
            for (final path in paths) {
              final lower = path.toLowerCase();
              final isPdf = lower.endsWith('.pdf');
              final metadata = isPdf
                  ? await const PdfMetadataService().read(path)
                  : PdfFileMetadata(title: _fileTitle(path));

              final provisionalUrl = 'local-file://${DateTime.now().microsecondsSinceEpoch}/$createdCount';
              final bookmarkId = await repository.create(
                url: provisionalUrl,
                title: metadata.title,
                tagNames: _splitNames(tags.text),
                status: status,
                rating: rating,
                inbox: inbox,
              );
              final attachments = await storage.importPathsForBookmark(
                bookmarkId: bookmarkId,
                profileDirectoryPath: profilePath,
                store: store,
                sourcePaths: [path],
              );
              if (attachments.isEmpty) continue;

              await repository.update(
                id: bookmarkId,
                url: Uri.file(attachments.first.path).toString(),
                title: metadata.title,
                tagNames: _splitNames(tags.text),
                status: status,
                rating: rating,
              );

              if (isPdf && metadata.authors.isNotEmpty) {
                for (final author in metadata.authors) {
                  try {
                    await repository.createPerson(author);
                  } catch (_, stackTrace) {
                    // Author enrichment is optional: preserve the imported
                    // bookmark while making unexpected failures observable in
                    // debug/test builds without logging user-provided names.
                    _debugAuthorCreationFailure(stackTrace);
                  }
                }
                final allPeople = await repository.watchPeople().first;
                final names = metadata.authors.map((e) => e.trim().toLowerCase()).toSet();
                final authors = allPeople.where((person) => names.contains(person.name.trim().toLowerCase())).toList();
                final allBookmarks = await repository.watchAll().first;
                final created = allBookmarks.where((item) => item.id == bookmarkId).firstOrNull;
                if (created != null && authors.isNotEmpty) {
                  await repository.setPeopleForRole(created, '著者', authors);
                }
              }
              createdCount++;
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$createdCount件のPDF / 動画ブックマークを作成しました')),
              );
            }
          } catch (error) {
            setLocalState(() => saving = false);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ファイルから作成できませんでした: $error')),
              );
            }
          } finally {
            await store?.dispose();
          }
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
                  OutlinedButton.icon(
                    onPressed: saving ? null : createFromFiles,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('PDF / 動画からブックマークを作成'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('またはURL', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
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
              child: Text(saving ? '取得中…' : 'URLから追加'),
            ),
          ],
        );
      },
    ),
  );

  url.dispose();
  tags.dispose();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
