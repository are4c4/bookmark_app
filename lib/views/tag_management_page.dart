import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';

class TagManagementPage extends StatelessWidget {
  const TagManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  Future<void> _createTag(BuildContext context, List<Tag> tags) async {
    final nameController = TextEditingController();
    Tag? parent;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('タグを追加'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'タグ名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Tag?>(
                  initialValue: parent,
                  decoration: const InputDecoration(
                    labelText: '親タグ',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<Tag?>(
                      value: null,
                      child: Text('なし（最上位）'),
                    ),
                    ...tags.map(
                      (tag) => DropdownMenuItem<Tag?>(
                        value: tag,
                        child: Text(tag.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setLocalState(() => parent = value),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  await repository.createTag(name, parent: parent);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {
                  setLocalState(() => error = '同名タグなどの理由で追加できませんでした');
                }
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
  }

  Future<void> _editTag(
    BuildContext context,
    Tag tag,
    List<Tag> allTags,
  ) async {
    final nameController = TextEditingController(text: tag.name);
    Tag? parent = tag.parentTagId == null
        ? null
        : allTags.where((item) => item.id == tag.parentTagId).firstOrNull;
    String? error;

    final descendants = _descendantIds(tag.id, allTags);
    final parentCandidates = allTags
        .where((candidate) =>
            candidate.id != tag.id && !descendants.contains(candidate.id))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('タグを編集'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'タグ名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Tag?>(
                  initialValue: parent,
                  decoration: const InputDecoration(
                    labelText: '親タグ',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<Tag?>(
                      value: null,
                      child: Text('なし（最上位）'),
                    ),
                    ...parentCandidates.map(
                      (candidate) => DropdownMenuItem<Tag?>(
                        value: candidate,
                        child: Text(candidate.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setLocalState(() => parent = value),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await repository.renameTag(tag, nameController.text);
                  await repository.setTagParent(tag, parent);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {
                  setLocalState(() => error = '変更を保存できませんでした');
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
  }

  Future<void> _deleteTag(BuildContext context, Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('タグを削除しますか？'),
        content: Text(
          '「${tag.name}」を削除します。\nブックマーク自体は削除されません。子タグは最上位へ移動します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) await repository.deleteTag(tag);
  }

  Set<int> _descendantIds(int tagId, List<Tag> tags) {
    final result = <int>{};
    void visit(int parentId) {
      for (final child in tags.where((tag) => tag.parentTagId == parentId)) {
        if (result.add(child.id)) visit(child.id);
      }
    }

    visit(tagId);
    return result;
  }

  List<Tag> _childrenOf(int? parentId, List<Tag> tags) => tags
      .where((tag) => tag.parentTagId == parentId)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Widget _tagTree(
    BuildContext context,
    List<Tag> tags,
    Map<int, int> counts,
    int? parentId,
    int depth,
  ) {
    final children = _childrenOf(parentId, tags);
    return Column(
      children: children.map((tag) {
        final nested = _childrenOf(tag.id, tags);
        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.only(
                left: 20 + depth * 28,
                right: 12,
              ),
              leading: Icon(
                nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined,
                size: 20,
              ),
              title: Text(tag.name),
              subtitle: Text('${counts[tag.id] ?? 0} 件のブックマーク'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _editTag(context, tag, tags);
                  if (value == 'delete') _deleteTag(context, tag);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('編集')),
                  PopupMenuItem(value: 'delete', child: Text('削除')),
                ],
              ),
            ),
            if (nested.isNotEmpty)
              _tagTree(context, tags, counts, tag.id, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('タグ管理'),
      ),
      floatingActionButton: StreamBuilder<List<Tag>>(
        stream: repository.watchTags(),
        builder: (context, snapshot) => FloatingActionButton.extended(
          onPressed: () => _createTag(context, snapshot.data ?? const <Tag>[]),
          icon: const Icon(Icons.add),
          label: const Text('タグを追加'),
        ),
      ),
      body: StreamBuilder<List<Tag>>(
        stream: repository.watchTags(),
        builder: (context, tagSnapshot) {
          final tags = tagSnapshot.data ?? const <Tag>[];
          return StreamBuilder<List<BookmarkItem>>(
            stream: repository.watchAll(),
            builder: (context, bookmarkSnapshot) {
              final bookmarks = bookmarkSnapshot.data ?? const <BookmarkItem>[];
              final counts = <int, int>{};
              for (final bookmark in bookmarks) {
                for (final tag in bookmark.tags) {
                  counts[tag.id] = (counts[tag.id] ?? 0) + 1;
                }
              }

              if (tags.isEmpty) {
                return const Center(
                  child: Text('タグがありません。右下から追加できます。'),
                );
              }

              return ListView(
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      'タグを階層化して整理できます。子タグは親タグの下に表示されます。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  _tagTree(context, tags, counts, null, 0),
                ],
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
