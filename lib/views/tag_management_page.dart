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
                  setLocalState(
                    () => error = '同名タグなどの理由で追加できませんでした',
                  );
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
        .where(
          (candidate) =>
              candidate.id != tag.id && !descendants.contains(candidate.id),
        )
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

  bool _canDropOn(Tag dragged, Tag target, List<Tag> tags) {
    if (dragged.id == target.id) return false;
    return !_descendantIds(dragged.id, tags).contains(target.id);
  }

  Widget _dragHandle(BuildContext context, Tag tag) {
    return Draggable<Tag>(
      data: tag,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 180, maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(tag.name)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: MouseRegion(
          cursor: SystemMouseCursors.grabbing,
          child: const Icon(Icons.drag_indicator, size: 18),
        ),
      ),
      child: Tooltip(
        message: 'ドラッグして親タグを変更',
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Icon(Icons.drag_indicator, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _tagTile(
    BuildContext context,
    Tag tag,
    List<Tag> tags,
    Map<int, int> counts,
    int depth,
  ) {
    final nested = _childrenOf(tag.id, tags);

    return DragTarget<Tag>(
      onWillAcceptWithDetails: (details) =>
          _canDropOn(details.data, tag, tags),
      onAcceptWithDetails: (details) async {
        await repository.setTagParent(details.data, tag);
      },
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: highlighted
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            borderRadius: BorderRadius.circular(8),
            border: highlighted
                ? Border.all(color: Theme.of(context).colorScheme.primary)
                : null,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.only(
              left: 16 + depth * 28,
              right: 12,
            ),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dragHandle(context, tag),
                const SizedBox(width: 4),
                Icon(
                  nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined,
                  size: 20,
                ),
              ],
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
        );
      },
    );
  }

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
            _tagTile(context, tag, tags, counts, depth),
            if (nested.isNotEmpty)
              _tagTree(context, tags, counts, tag.id, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _rootDropTarget(BuildContext context) {
    return DragTarget<Tag>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) async {
        await repository.setTagParent(details.data, null);
      },
      builder: (context, candidates, rejected) {
        final active = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.vertical_align_top,
                color: active ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: 10),
              Text(
                active ? 'ここにドロップして最上位へ移動' : '最上位へ移動',
              ),
            ],
          ),
        );
      },
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
          onPressed: () => _createTag(
            context,
            snapshot.data ?? const <Tag>[],
          ),
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
              final bookmarks =
                  bookmarkSnapshot.data ?? const <BookmarkItem>[];
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                    child: Text(
                      '左端のドラッグハンドルを掴んで別のタグへドロップすると、そのタグの子にできます。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  _rootDropTarget(context),
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
