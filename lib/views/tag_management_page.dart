import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/tag_group_store.dart';
import '../widgets/bookmark_reverse_lookup_dialog.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  late final TagGroupStore _groupStore;
  var _ready = false;

  BookmarkRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _groupStore = TagGroupStore(repository.lifecycleStore.database);
    _initialize();
  }

  Future<void> _initialize() async {
    await _groupStore.initialize();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _groupStore.dispose();
    super.dispose();
  }

  Future<String?> _askName(String title, {String initial = ''}) async {
    var value = initial;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, value.trim()), child: const Text('保存')),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = await _askName('タググループを追加');
    if (name?.isNotEmpty != true) return;
    try {
      await _groupStore.createGroup(name!);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('グループを追加できませんでした: $error')));
      }
    }
  }

  Future<void> _renameGroup(TagGroupInfo group) async {
    final name = await _askName('グループ名を変更', initial: group.name);
    if (name?.isNotEmpty != true || name == group.name) return;
    await _groupStore.renameGroup(group.id, name!);
  }

  Future<void> _deleteGroup(TagGroupInfo group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「${group.name}」を削除しますか？'),
        content: const Text('グループだけを削除します。中のタグは削除されず「その他タグ」へ移動します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok == true) await _groupStore.deleteGroup(group.id);
  }

  List<Tag> _childrenOf(int? parentId, List<Tag> tags, Set<int> allowedIds) => tags
      .where((tag) => tag.parentTagId == parentId && allowedIds.contains(tag.id))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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

  Future<void> _createTag(
    List<Tag> tags,
    List<TagGroupInfo> groups,
    Map<int, int?> groupByTag, {
    int? initialGroupId,
  }) async {
    var name = '';
    Tag? parent;
    int? groupId = initialGroupId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final parentCandidates = tags.where((tag) => groupByTag[tag.id] == groupId).toList();
          if (parent != null && !parentCandidates.any((tag) => tag.id == parent!.id)) parent = null;
          return AlertDialog(
            title: const Text('タグを追加'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'タグ名'),
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: groupId,
                    decoration: const InputDecoration(labelText: 'タググループ'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('グループなし')),
                      ...groups.map((group) => DropdownMenuItem<int?>(value: group.id, child: Text(group.name))),
                    ],
                    onChanged: (value) => setLocalState(() {
                      groupId = value;
                      parent = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: parent?.id,
                    decoration: const InputDecoration(labelText: '親タグ'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('なし（最上位）')),
                      ...parentCandidates.map((tag) => DropdownMenuItem<int?>(value: tag.id, child: Text(tag.name))),
                    ],
                    onChanged: (value) => setLocalState(() {
                      parent = value == null ? null : parentCandidates.firstWhere((tag) => tag.id == value);
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('追加')),
            ],
          );
        },
      ),
    );

    if (ok != true || name.trim().isEmpty) return;
    final id = await repository.createTag(name.trim(), parent: parent);
    await _groupStore.setTagGroup(id, groupId);
  }

  Future<void> _editTag(
    Tag tag,
    List<Tag> tags,
    List<TagGroupInfo> groups,
    Map<int, int?> groupByTag,
  ) async {
    var name = tag.name;
    var groupId = groupByTag[tag.id];
    final descendants = _descendantIds(tag.id, tags);
    Tag? parent = tag.parentTagId == null
        ? null
        : tags.where((item) => item.id == tag.parentTagId).firstOrNull;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final parentCandidates = tags
              .where((candidate) =>
                  candidate.id != tag.id &&
                  !descendants.contains(candidate.id) &&
                  groupByTag[candidate.id] == groupId)
              .toList();
          if (parent != null && !parentCandidates.any((candidate) => candidate.id == parent!.id)) parent = null;
          return AlertDialog(
            title: const Text('タグを編集'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'タグ名'),
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: groupId,
                    decoration: const InputDecoration(labelText: 'タググループ'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('グループなし')),
                      ...groups.map((group) => DropdownMenuItem<int?>(value: group.id, child: Text(group.name))),
                    ],
                    onChanged: (value) => setLocalState(() {
                      groupId = value;
                      parent = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: parent?.id,
                    decoration: const InputDecoration(labelText: '親タグ'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('なし（最上位）')),
                      ...parentCandidates.map((candidate) => DropdownMenuItem<int?>(value: candidate.id, child: Text(candidate.name))),
                    ],
                    onChanged: (value) => setLocalState(() {
                      parent = value == null ? null : parentCandidates.firstWhere((candidate) => candidate.id == value);
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
            ],
          );
        },
      ),
    );

    if (ok != true || name.trim().isEmpty) return;
    await repository.renameTag(tag, name.trim());
    await repository.setTagParent(tag, parent);
    await _groupStore.setTagGroup(tag.id, groupId);
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('タグを削除しますか？'),
        content: Text('「${tag.name}」を削除します。ブックマーク自体は削除されません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed == true) await repository.deleteTag(tag);
  }

  Future<void> _showRelatedBookmarks(
    Tag tag,
    List<Tag> allTags, {
    bool includeDescendants = false,
  }) {
    final tagIds = <int>{tag.id};
    if (includeDescendants) tagIds.addAll(_descendantIds(tag.id, allTags));
    final stream = repository.watchAll().map(
          (bookmarks) => bookmarks
              .where((bookmark) => bookmark.tags.any((bookmarkTag) => tagIds.contains(bookmarkTag.id)))
              .toList(),
        );
    return showBookmarkReverseLookupDialog(
      context: context,
      title: '${tag.name} のブックマーク${includeDescendants ? '（子タグを含む）' : ''}',
      bookmarks: stream,
    );
  }

  Widget _tagTree(
    List<Tag> allTags,
    Set<int> allowedIds,
    Map<int, int> counts,
    List<TagGroupInfo> groups,
    Map<int, int?> groupByTag,
    int? parentId,
    int depth,
  ) {
    final children = _childrenOf(parentId, allTags, allowedIds);
    return Column(
      children: children.map((tag) {
        final nested = _childrenOf(tag.id, allTags, allowedIds);
        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.only(left: 16 + depth * 24, right: 8),
              leading: Icon(nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined, size: 19),
              title: Text(tag.name),
              subtitle: Text('${counts[tag.id] ?? 0} 件'),
              onTap: () => _showRelatedBookmarks(tag, allTags),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'desc') _showRelatedBookmarks(tag, allTags, includeDescendants: true);
                  if (value == 'edit') _editTag(tag, allTags, groups, groupByTag);
                  if (value == 'delete') _deleteTag(tag);
                },
                itemBuilder: (_) => [
                  if (nested.isNotEmpty) const PopupMenuItem(value: 'desc', child: Text('子タグも含めて見る')),
                  const PopupMenuItem(value: 'edit', child: Text('編集')),
                  const PopupMenuItem(value: 'delete', child: Text('削除')),
                ],
              ),
            ),
            if (nested.isNotEmpty)
              _tagTree(allTags, allowedIds, counts, groups, groupByTag, tag.id, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _groupSection(
    TagGroupInfo? group,
    List<Tag> tags,
    Map<int, int?> groupByTag,
    Map<int, int> counts,
    List<TagGroupInfo> groups,
  ) {
    final ids = tags
        .where((tag) => groupByTag[tag.id] == group?.id)
        .map((tag) => tag.id)
        .toSet();
    if (ids.isEmpty && group == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(group?.name ?? 'その他タグ', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${ids.length} タグ'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'このグループにタグを追加',
                    onPressed: () => _createTag(tags, groups, groupByTag, initialGroupId: group?.id),
                    icon: const Icon(Icons.add),
                  ),
                  if (group != null)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rename') _renameGroup(group);
                        if (value == 'delete') _deleteGroup(group);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('グループ名を変更')),
                        PopupMenuItem(value: 'delete', child: Text('グループを削除')),
                      ],
                    ),
                ],
              ),
            ),
            if (ids.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Align(alignment: Alignment.centerLeft, child: Text('タグはまだありません')),
              )
            else
              _tagTree(tags, ids, counts, groups, groupByTag, null, 0),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('タグ管理'),
        actions: [
          TextButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: const Text('グループを追加'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: StreamBuilder<List<Tag>>(
        stream: repository.watchTags(),
        builder: (context, tagSnapshot) => StreamBuilder<List<TagGroupInfo>>(
          stream: _groupStore.watchGroups(),
          builder: (context, groupSnapshot) => StreamBuilder<Map<int, int?>>(
            stream: _groupStore.watchTagGroupIds(),
            builder: (context, mapSnapshot) => FloatingActionButton.extended(
              onPressed: () => _createTag(
                tagSnapshot.data ?? const <Tag>[],
                groupSnapshot.data ?? const <TagGroupInfo>[],
                mapSnapshot.data ?? const <int, int?>{},
              ),
              icon: const Icon(Icons.add),
              label: const Text('タグを追加'),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Tag>>(
        stream: repository.watchTags(),
        builder: (context, tagSnapshot) => StreamBuilder<List<TagGroupInfo>>(
          stream: _groupStore.watchGroups(),
          builder: (context, groupSnapshot) => StreamBuilder<Map<int, int?>>(
            stream: _groupStore.watchTagGroupIds(),
            builder: (context, mapSnapshot) => StreamBuilder<List<BookmarkItem>>(
              stream: repository.watchAll(),
              builder: (context, bookmarkSnapshot) {
                final tags = tagSnapshot.data ?? const <Tag>[];
                final groups = groupSnapshot.data ?? const <TagGroupInfo>[];
                final groupByTag = mapSnapshot.data ?? const <int, int?>{};
                final bookmarks = bookmarkSnapshot.data ?? const <BookmarkItem>[];
                final counts = <int, int>{};
                for (final bookmark in bookmarks) {
                  for (final tag in bookmark.tags) {
                    counts[tag.id] = (counts[tag.id] ?? 0) + 1;
                  }
                }

                return ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text(
                        'タググループは「テーマ」「用途」「難易度」など、独立した分類軸として使えます。親子関係は各グループ内で作れます。',
                      ),
                    ),
                    ...groups.map((group) => _groupSection(group, tags, groupByTag, counts, groups)),
                    _groupSection(null, tags, groupByTag, counts, groups),
                    if (groups.isEmpty && tags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('タググループまたはタグを追加してください')),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
