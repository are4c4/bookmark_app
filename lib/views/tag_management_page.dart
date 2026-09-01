import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/tag_group_store.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_toast.dart';
import '../widgets/bookmark_reverse_lookup_dialog.dart';
import '../widgets/tag_detail_pane.dart';
import '../widgets/tag_tree_view.dart';
import 'tag_tree_model.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  late final TagGroupStore _store;
  final _searchController = TextEditingController();
  final _treeFocus = FocusNode(debugLabel: 'tag-tree');
  final Set<int> _expandedTagIds = {};
  final Set<int> _expandedGroupIds = {};
  final Set<int> _multiSelectedIds = {};

  bool _ready = false;
  bool _dragging = false;
  bool _dragCancelled = false;
  String _query = '';
  TagUsageFilter _filter = TagUsageFilter.all;
  int? _selectedTagId;
  String? _focusedKey;
  int? _editingTagId;
  TextEditingController? _editController;
  String? _editError;
  String? _creatingUnderKey;
  int? _creatingGroupId;
  int? _creatingParentId;
  TextEditingController? _createController;
  String? _createError;

  List<Tag> _tags = const [];
  List<TagGroupInfo> _groups = const [];
  Map<int, int?> _groupByTag = const {};
  Map<int, TagUsageStats> _usage = const {};
  TagTreeModel _model = const TagTreeModel(
    rows: [],
    matchingTagIds: {},
    allowedTagIds: {},
  );

  BookmarkRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _store = TagGroupStore(repository.lifecycleStore.database);
    _initialize();
  }

  Future<void> _initialize() async {
    await _store.initialize();
    final state = await _store.loadExpansionState();
    _expandedTagIds.addAll(state.tagIds);
    _expandedGroupIds.addAll(state.groupIds);
    if (!state.hasPersistedValue) {
      final tags = await repository.watchTags().first;
      final groups = await _store.listGroups();
      final parentIds = tags
          .map((tag) => tag.parentTagId)
          .whereType<int>()
          .toSet();
      _expandedTagIds.addAll(parentIds);
      _expandedGroupIds
        ..addAll(groups.map((group) => group.id))
        ..add(-1);
      await _saveExpansion();
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _editController?.dispose();
    _createController?.dispose();
    _searchController.dispose();
    _treeFocus.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _saveExpansion() => _store.saveExpansionState(
        TagTreeExpansionState(
          tagIds: _expandedTagIds,
          groupIds: _expandedGroupIds,
          hasPersistedValue: true,
        ),
      );

  Tag? _tagById(int? id) {
    if (id == null) return null;
    for (final tag in _tags) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  TagGroupInfo? _groupById(int? id) {
    if (id == null) return null;
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  Set<int> _descendants(int tagId) {
    final result = <int>{};
    void visit(int parentId) {
      for (final child in _tags.where(
        (tag) => tag.parentTagId == parentId,
      )) {
        if (result.add(child.id)) visit(child.id);
      }
    }

    visit(tagId);
    return result;
  }

  void _focusRow(String key) {
    _treeFocus.requestFocus();
    setState(() => _focusedKey = key);
  }

  void _selectTag(Tag tag) {
    if (_editingTagId != null && _editingTagId != tag.id) {
      _cancelRename();
    }
    setState(() {
      _selectedTagId = tag.id;
      _focusedKey = 'tag:${tag.id}';
    });
  }

  void _toggleGroup(int? groupId) {
    if (_query.isNotEmpty || _filter != TagUsageFilter.all) return;
    final key = groupId ?? -1;
    setState(() {
      if (!_expandedGroupIds.add(key)) _expandedGroupIds.remove(key);
    });
    _saveExpansion();
  }

  void _toggleTag(Tag tag) {
    if (_query.isNotEmpty || _filter != TagUsageFilter.all) return;
    setState(() {
      if (!_expandedTagIds.add(tag.id)) {
        _expandedTagIds.remove(tag.id);
      }
    });
    _saveExpansion();
  }

  Future<void> _expandAll() async {
    final parents =
        _tags.map((tag) => tag.parentTagId).whereType<int>().toSet();
    setState(() {
      _expandedTagIds
        ..clear()
        ..addAll(parents);
      _expandedGroupIds
        ..clear()
        ..addAll(_groups.map((group) => group.id))
        ..add(-1);
    });
    await _saveExpansion();
  }

  Future<void> _collapseAll() async {
    setState(() {
      _expandedTagIds.clear();
      _expandedGroupIds.clear();
    });
    await _saveExpansion();
  }

  void _beginRename(Tag tag) {
    _cancelInlineCreate();
    _editController?.dispose();
    setState(() {
      _editingTagId = tag.id;
      _editController = TextEditingController(text: tag.name)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: tag.name.length,
        );
      _editError = null;
      _selectedTagId = tag.id;
    });
  }

  Future<void> _submitRename(Tag tag) async {
    final value = _editController?.text.trim() ?? '';
    if (value.isEmpty) {
      setState(() => _editError = 'タグ名を入力してください');
      return;
    }
    try {
      await _store.renameTag(tag.id, value);
      _cancelRename();
    } catch (error) {
      if (mounted) setState(() => _editError = '$error');
    }
  }

  void _cancelRename() {
    _editController?.dispose();
    _editController = null;
    if (mounted) {
      setState(() {
        _editingTagId = null;
        _editError = null;
      });
    }
  }

  void _beginInlineCreate({int? groupId, Tag? parent}) {
    if (_query.isNotEmpty || _filter != TagUsageFilter.all) {
      setState(() {
        _query = '';
        _filter = TagUsageFilter.all;
        _searchController.clear();
      });
    }
    if (_editingTagId != null) _cancelRename();
    _createController?.dispose();
    final resolvedGroupId = parent == null
        ? groupId
        : (_groupByTag[parent.id] ?? parent.groupId);
    final parentKey = parent == null
        ? 'group:${groupId ?? 'other'}'
        : 'tag:${parent.id}';
    setState(() {
      _creatingUnderKey = parentKey;
      _creatingGroupId = resolvedGroupId;
      _creatingParentId = parent?.id;
      _createController = TextEditingController();
      _createError = null;
      _focusedKey = parentKey;
      if (parent != null) {
        _expandedTagIds.add(parent.id);
      } else {
        _expandedGroupIds.add(groupId ?? -1);
      }
    });
    _saveExpansion();
  }

  Future<void> _submitInlineCreate() async {
    final name = _createController?.text.trim() ?? '';
    if (name.isEmpty) {
      if (mounted) setState(() => _createError = 'タグ名を入力してください');
      return;
    }
    final groupId = _creatingGroupId;
    final parentId = _creatingParentId;
    try {
      final id = await repository.createTag(name);
      await _store.moveTag(
        tagId: id,
        parentTagId: parentId,
        groupId: groupId,
      );
      if (!mounted) return;
      _createController?.dispose();
      _createController = null;
      setState(() {
        _creatingUnderKey = null;
        _creatingGroupId = null;
        _creatingParentId = null;
        _createError = null;
        _selectedTagId = id;
        _focusedKey = 'tag:$id';
        _expandedGroupIds.add(groupId ?? -1);
        if (parentId != null) _expandedTagIds.add(parentId);
      });
      await _saveExpansion();
      _treeFocus.requestFocus();
    } catch (error) {
      if (mounted) setState(() => _createError = '$error');
    }
  }

  void _cancelInlineCreate() {
    _createController?.dispose();
    _createController = null;
    if (mounted) {
      setState(() {
        _creatingUnderKey = null;
        _creatingGroupId = null;
        _creatingParentId = null;
        _createError = null;
      });
    }
  }

  void _toggleMulti(Tag tag) {
    setState(() {
      if (!_multiSelectedIds.add(tag.id)) {
        _multiSelectedIds.remove(tag.id);
      }
      _selectedTagId = tag.id;
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_dragging) {
        setState(() => _dragCancelled = true);
      } else if (_creatingUnderKey != null) {
        _cancelInlineCreate();
      } else if (_editingTagId != null) {
        _cancelRename();
      } else if (_multiSelectedIds.isNotEmpty) {
        setState(() => _multiSelectedIds.clear());
      }
      return KeyEventResult.handled;
    }
    if (_editingTagId != null || _creatingUnderKey != null) {
      return KeyEventResult.ignored;
    }
    if (_model.rows.isEmpty) return KeyEventResult.ignored;

    var index = _model.rows.indexWhere(
      (row) => row.focusKey == _focusedKey,
    );
    if (index < 0) index = 0;

    void focusIndex(int next) {
      final clamped = next.clamp(0, _model.rows.length - 1);
      final row = _model.rows[clamped];
      setState(() {
        _focusedKey = row.focusKey;
        if (row.tag != null) _selectedTagId = row.tag!.id;
      });
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      focusIndex(index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      focusIndex(index + 1);
      return KeyEventResult.handled;
    }
    final row = _model.rows[index];
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (row.kind == TagTreeRowKind.group && row.expanded) {
        _toggleGroup(row.groupId);
      } else if (row.tag != null && row.expanded && row.hasChildren) {
        _toggleTag(row.tag!);
      } else if (row.tag?.parentTagId != null) {
        final parentKey = 'tag:${row.tag!.parentTagId}';
        final parentIndex =
            _model.rows.indexWhere((candidate) => candidate.focusKey == parentKey);
        if (parentIndex >= 0) focusIndex(parentIndex);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (row.kind == TagTreeRowKind.group && !row.expanded) {
        _toggleGroup(row.groupId);
      } else if (row.tag != null && row.hasChildren && !row.expanded) {
        _toggleTag(row.tag!);
      } else if (index + 1 < _model.rows.length) {
        focusIndex(index + 1);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && row.tag != null) {
      _beginRename(row.tag!);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space && row.tag != null) {
      _toggleMulti(row.tag!);
      return KeyEventResult.handled;
    }
    if ((event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) &&
        row.tag != null) {
      _deleteTag(row.tag!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _canDrop(Tag dragged, TagTreeRow target) {
    if (_dragCancelled) return false;
    if (target.tag == null) return true;
    if (dragged.id == target.tag!.id) return false;
    return !_descendants(dragged.id).contains(target.tag!.id);
  }

  Future<void> _drop(Tag dragged, TagTreeRow target) async {
    if (_dragCancelled) return;
    try {
      final snapshot = await _store.moveTag(
        tagId: dragged.id,
        parentTagId: target.tag?.id,
        groupId: target.tag == null ? target.groupId : null,
      );
      if (!mounted) return;
      final destination = target.tag == null
          ? '${target.label}の最上位'
          : '「${target.tag!.name}」の子';
      showAppToast(
        context,
        '「${dragged.name}」を$destinationへ移動しました',
        actionLabel: '元に戻す',
        onAction: () => _store.restoreMove(snapshot),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移動できませんでした: $error')),
      );
    }
  }

  Future<String?> _askName(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim(),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _createGroup() async {
    final name = await _askName('タググループを追加');
    if (name?.isNotEmpty != true) return;
    try {
      await _store.createGroup(name!);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('グループを追加できませんでした: $error')),
        );
      }
    }
  }

  Future<void> _deleteGroup(TagGroupInfo group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${group.name}」を削除しますか？'),
        content: const Text(
          'グループ内のタグは削除せず、「その他タグ」へ移動します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.deleteGroup(group.id);
  }

  Future<void> _manageGroups() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('タググループ管理'),
        content: SizedBox(
          width: 440,
          child: StreamBuilder<List<TagGroupInfo>>(
            stream: _store.watchGroups(),
            builder: (context, snapshot) {
              final groups = snapshot.data ?? const <TagGroupInfo>[];
              if (groups.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(UiTokens.space16),
                  child: Text('グループはありません'),
                );
              }
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final group in groups)
                    ListTile(
                      title: Text(group.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '名前変更',
                            onPressed: () async {
                              final name = await _askName(
                                'グループ名を変更',
                                initial: group.name,
                              );
                              if (name?.isNotEmpty == true) {
                                await _store.renameGroup(group.id, name!);
                              }
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '削除',
                            onPressed: () => _deleteGroup(group),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTag({int? initialGroupId, int? initialParentId}) async {
    var name = '';
    int? groupId = initialGroupId;
    int? parentId = initialParentId;
    if (parentId != null) {
      final parent = _tagById(parentId);
      if (parent != null) {
        groupId = _groupByTag[parent.id] ?? parent.groupId;
      }
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final parentCandidates = _tags
              .where(
                (tag) => (_groupByTag[tag.id] ?? tag.groupId) == groupId,
              )
              .toList();
          return AlertDialog(
            title: const Text('タグを追加'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'タグ名'),
                    onChanged: (value) => name = value,
                    onSubmitted: (_) => Navigator.pop(dialogContext, true),
                  ),
                  const SizedBox(height: UiTokens.space12),
                  DropdownButtonFormField<int?>(
                    initialValue: groupId,
                    decoration: const InputDecoration(
                      labelText: 'タググループ',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('その他タグ'),
                      ),
                      for (final group in _groups)
                        DropdownMenuItem<int?>(
                          value: group.id,
                          child: Text(group.name),
                        ),
                    ],
                    onChanged: (value) => setLocalState(() {
                      groupId = value;
                      parentId = null;
                    }),
                  ),
                  const SizedBox(height: UiTokens.space12),
                  DropdownButtonFormField<int?>(
                    initialValue: parentId,
                    decoration: const InputDecoration(labelText: '親タグ'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('なし（最上位）'),
                      ),
                      for (final tag in parentCandidates)
                        DropdownMenuItem<int?>(
                          value: tag.id,
                          child: Text(tag.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => parentId = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || name.trim().isEmpty) return;
    final id = await repository.createTag(name.trim());
    await _store.moveTag(
      tagId: id,
      parentTagId: parentId,
      groupId: groupId,
    );
    if (!mounted) return;
    setState(() {
      _expandedGroupIds.add(groupId ?? -1);
      if (parentId != null) _expandedTagIds.add(parentId!);
      _selectedTagId = id;
      _focusedKey = 'tag:$id';
    });
    await _saveExpansion();
  }

  Future<void> _moveDialog(Tag tag) async {
    var groupId = _groupByTag[tag.id] ?? tag.groupId;
    var parentId = tag.parentTagId;
    final forbidden = _descendants(tag.id)..add(tag.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final candidates = _tags
              .where(
                (candidate) =>
                    !forbidden.contains(candidate.id) &&
                    (_groupByTag[candidate.id] ?? candidate.groupId) ==
                        groupId,
              )
              .toList();
          if (parentId != null &&
              !candidates.any((candidate) => candidate.id == parentId)) {
            parentId = null;
          }
          return AlertDialog(
            title: Text('「${tag.name}」を移動'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: groupId,
                    decoration:
                        const InputDecoration(labelText: 'タググループ'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('その他タグ'),
                      ),
                      for (final group in _groups)
                        DropdownMenuItem<int?>(
                          value: group.id,
                          child: Text(group.name),
                        ),
                    ],
                    onChanged: (value) => setLocalState(() {
                      groupId = value;
                      parentId = null;
                    }),
                  ),
                  const SizedBox(height: UiTokens.space12),
                  DropdownButtonFormField<int?>(
                    initialValue: parentId,
                    decoration: const InputDecoration(labelText: '親タグ'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('なし（最上位）'),
                      ),
                      for (final candidate in candidates)
                        DropdownMenuItem<int?>(
                          value: candidate.id,
                          child: Text(candidate.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => parentId = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('移動'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final snapshot = await _store.moveTag(
      tagId: tag.id,
      parentTagId: parentId,
      groupId: groupId,
    );
    if (!mounted) return;
    showAppToast(
      context,
      '「${tag.name}」を移動しました',
      actionLabel: '元に戻す',
      onAction: () => _store.restoreMove(snapshot),
    );
  }

  Future<void> _mergeTag(Tag source) async {
    final forbidden = _descendants(source.id)..add(source.id);
    final candidates =
        _tags.where((tag) => !forbidden.contains(tag.id)).toList();
    if (candidates.isEmpty) return;
    var targetId = candidates.first.id;
    final impact = await _store.mergeImpact(source.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('「${source.name}」を統合'),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: targetId,
                  decoration: const InputDecoration(labelText: '統合先タグ'),
                  items: [
                    for (final tag in candidates)
                      DropdownMenuItem(
                        value: tag.id,
                        child: Text(tag.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setLocalState(() => targetId = value);
                  },
                ),
                const SizedBox(height: UiTokens.space16),
                Text('影響するブックマーク: ${impact.bookmarkCount}件'),
                Text('保存ビュー: ${impact.savedViewCount}件'),
                Text(
                  '自動整理ルール: ${impact.autoOrganizeRuleCount}件',
                ),
                const SizedBox(height: UiTokens.space12),
                const Text(
                  '統合元の子タグは統合先の子へ移動します。'
                  'ブックマーク本体は削除されません。',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('統合'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _store.mergeTags(
      sourceTagId: source.id,
      targetTagId: targetId,
    );
    if (mounted) {
      setState(() {
        _selectedTagId = targetId;
        _multiSelectedIds.remove(source.id);
      });
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    final stats = _usage[tag.id] ??
        const TagUsageStats(directCount: 0, aggregateCount: 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${tag.name}」を削除しますか？'),
        content: Text(
          '直接使用 ${stats.directCount}件、子孫を含む '
          '${stats.aggregateCount}件です。タグの関連だけが削除され、'
          'ブックマーク本体は削除されません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteTag(tag.id);
    if (mounted) {
      setState(() {
        _selectedTagId = null;
        _multiSelectedIds.remove(tag.id);
      });
    }
  }

  Future<void> _deleteSelectedUnused() async {
    final selected = _multiSelectedIds
        .map(_tagById)
        .whereType<Tag>()
        .toList();
    final deletable = selected
        .where((tag) => (_usage[tag.id]?.aggregateCount ?? 0) == 0)
        .toList();
    final protectedCount = selected.length - deletable.length;
    if (deletable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('使用中の子孫を持つタグは一括削除できません'),
        ),
      );
      return;
    }
    final names = deletable.map((tag) => tag.name).join('、');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${deletable.length}件の未使用タグを削除'),
        content: Text(
          '$names\n\n'
          '${protectedCount > 0 ? '使用中の子孫を持つ$protectedCount件は除外します。' : ''}'
          'ブックマーク本体は削除されません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteUnusedTags(deletable.map((tag) => tag.id));
    if (mounted) setState(() => _multiSelectedIds.clear());
  }

  Future<void> _showRelated(
    Tag tag, {
    required bool includeDescendants,
  }) {
    final ids = <int>{tag.id};
    if (includeDescendants) ids.addAll(_descendants(tag.id));
    return showBookmarkReverseLookupDialog(
      context: context,
      title: '${tag.name} のブックマーク'
          '${includeDescendants ? '（子孫を含む）' : ''}',
      bookmarks: repository.watchAll().map(
            (bookmarks) => bookmarks
                .where(
                  (bookmark) => bookmark.tags.any(
                    (bookmarkTag) => ids.contains(bookmarkTag.id),
                  ),
                )
                .toList(),
          ),
    );
  }

  void _menuAction(Tag tag, String action) {
    switch (action) {
      case 'add-child':
        _beginInlineCreate(parent: tag);
      case 'rename':
        _beginRename(tag);
      case 'move':
        _moveDialog(tag);
      case 'root':
        _store
            .moveTag(
              tagId: tag.id,
              groupId: _groupByTag[tag.id] ?? tag.groupId,
            )
            .then((snapshot) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${tag.name}」を最上位へ移動しました'),
              action: SnackBarAction(
                label: '元に戻す',
                onPressed: () => _store.restoreMove(snapshot),
              ),
            ),
          );
        });
      case 'merge':
        _mergeTag(tag);
      case 'delete':
        _deleteTag(tag);
    }
  }

  void _groupMenuAction(int? groupId, String action) {
    switch (action) {
      case 'add':
        _beginInlineCreate(groupId: groupId);
    }
  }

  Future<void> _showKeyboardHelp() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('タグツリーのキーボード操作'),
          content: const Text(
            '↑ / ↓  前後の行へ移動\n'
            '← / →  折りたたみ・展開・親子移動\n'
            'Enter  名前変更\n'
            'Space  複数選択\n'
            'Delete / Backspace  削除確認\n'
            'Escape  編集・タグ追加・複数選択を解除',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: UiTokens.appBarHeight,
        title: const Text(
          'タグ管理',
          style: TextStyle(fontSize: UiTokens.textLg),
        ),
        actions: [
          IconButton(
            tooltip: 'キーボード操作',
            onPressed: _showKeyboardHelp,
            icon: const Icon(Icons.keyboard_outlined),
          ),
          TextButton.icon(
            onPressed: _manageGroups,
            icon: const Icon(
              Icons.category_outlined,
              size: UiTokens.iconNormal,
            ),
            label: const Text('グループ管理'),
          ),
          TextButton.icon(
            onPressed: _createGroup,
            icon: const Icon(
              Icons.create_new_folder_outlined,
              size: UiTokens.iconNormal,
            ),
            label: const Text('グループ追加'),
          ),
          const SizedBox(width: UiTokens.space8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTag(),
        icon: const Icon(Icons.add),
        label: const Text('タグを追加'),
      ),
      body: StreamBuilder<List<Tag>>(
        stream: repository.watchTags(),
        builder: (context, tagSnapshot) =>
            StreamBuilder<List<TagGroupInfo>>(
          stream: _store.watchGroups(),
          builder: (context, groupSnapshot) =>
              StreamBuilder<Map<int, int?>>(
            stream: _store.watchTagGroupIds(),
            builder: (context, groupMapSnapshot) =>
                StreamBuilder<Map<int, TagUsageStats>>(
              stream: _store.watchUsageStats(),
              builder: (context, usageSnapshot) {
                _tags = tagSnapshot.data ?? const <Tag>[];
                _groups =
                    groupSnapshot.data ?? const <TagGroupInfo>[];
                _groupByTag =
                    groupMapSnapshot.data ?? const <int, int?>{};
                _usage =
                    usageSnapshot.data ?? const <int, TagUsageStats>{};
                _multiSelectedIds.removeWhere(
                  (id) => !_tags.any((tag) => tag.id == id),
                );
                _model = TagTreeModel.build(
                  tags: _tags,
                  groups: _groups,
                  groupByTag: _groupByTag,
                  usage: _usage,
                  expandedTagIds: _expandedTagIds,
                  expandedGroupIds: _expandedGroupIds,
                  query: _query,
                  filter: _filter,
                );
                if (_focusedKey != null &&
                    !_model.rows.any(
                      (row) => row.focusKey == _focusedKey,
                    )) {
                  _focusedKey = _model.rows.isEmpty
                      ? null
                      : _model.rows.first.focusKey;
                }
                return _buildBody();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final selected = _tagById(_selectedTagId);
    final parent = _tagById(selected?.parentTagId);
    final group = _groupById(
      selected == null
          ? null
          : (_groupByTag[selected.id] ?? selected.groupId),
    );
    final childCount = selected == null
        ? 0
        : _tags.where((tag) => tag.parentTagId == selected.id).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDetails = constraints.maxWidth >= 900;
        return Column(
          children: [
            _toolbar(),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      focusNode: _treeFocus,
                      autofocus: true,
                      onKeyEvent: _handleKey,
                      child: TagTreeView(
                        model: _model,
                        query: _query,
                        selectedTagId: _selectedTagId,
                        focusedKey: _focusedKey,
                        multiSelectedIds: _multiSelectedIds,
                        editingTagId: _editingTagId,
                        editController: _editController,
                        editError: _editError,
                        creatingUnderKey: _creatingUnderKey,
                        createController: _createController,
                        createError: _createError,
                        onSelectTag: _selectTag,
                        onFocusRow: _focusRow,
                        onToggleGroup: _toggleGroup,
                        onToggleTag: _toggleTag,
                        onToggleMultiSelect: _toggleMulti,
                        onBeginRename: _beginRename,
                        onSubmitRename: _submitRename,
                        onCancelRename: _cancelRename,
                        onAddToGroup: (groupId) =>
                            _beginInlineCreate(groupId: groupId),
                        onAddChild: (tag) =>
                            _beginInlineCreate(parent: tag),
                        onGroupMenuAction: _groupMenuAction,
                        onSubmitCreate: _submitInlineCreate,
                        onCancelCreate: _cancelInlineCreate,
                        onMenuAction: _menuAction,
                        onDrop: _drop,
                        canDrop: _canDrop,
                        onShowDirect: (tag) => _showRelated(
                          tag,
                          includeDescendants: false,
                        ),
                        onShowAggregate: (tag) => _showRelated(
                          tag,
                          includeDescendants: true,
                        ),
                        onDragStarted: (_) => setState(() {
                          _dragging = true;
                          _dragCancelled = false;
                        }),
                        onDragEnded: () => setState(() {
                          _dragging = false;
                          _dragCancelled = false;
                        }),
                      ),
                    ),
                  ),
                  if (showDetails)
                    SizedBox(
                      width: 330,
                      child: TagDetailPane(
                        tag: selected,
                        usage:
                            selected == null ? null : _usage[selected.id],
                        parent: parent,
                        group: group,
                        childCount: childCount,
                        onRename: selected == null
                            ? () {}
                            : () => _beginRename(selected),
                        onMove: selected == null
                            ? () {}
                            : () => _moveDialog(selected),
                        onMerge: selected == null
                            ? () {}
                            : () => _mergeTag(selected),
                        onDelete: selected == null
                            ? () {}
                            : () => _deleteTag(selected),
                        onShowDirect: selected == null
                            ? () {}
                            : () => _showRelated(
                                  selected,
                                  includeDescendants: false,
                                ),
                        onShowAggregate: selected == null
                            ? () {}
                            : () => _showRelated(
                                  selected,
                                  includeDescendants: true,
                                ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar() => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UiTokens.space12,
          vertical: UiTokens.space8,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'タグを検索',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: UiTokens.iconNormal,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '検索を解除',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(width: UiTokens.space12),
            SegmentedButton<TagUsageFilter>(
              showSelectedIcon: false,
              segments: [
                for (final filter in TagUsageFilter.values)
                  ButtonSegment(
                    value: filter,
                    label: Text(filter.label),
                  ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  setState(() => _filter = selection.first);
                }
              },
            ),
            const Spacer(),
            if (_filter == TagUsageFilter.unused)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _multiSelectedIds
                      ..clear()
                      ..addAll(
                        _tags
                            .where(
                              (tag) =>
                                  (_usage[tag.id]?.directCount ?? 0) == 0,
                            )
                            .map((tag) => tag.id),
                      );
                  });
                },
                icon: const Icon(Icons.select_all, size: 17),
                label: const Text('未使用を選択'),
              ),
            if (_multiSelectedIds.isNotEmpty)
              FilledButton.tonalIcon(
                onPressed: _deleteSelectedUnused,
                icon: const Icon(Icons.delete_outline, size: 17),
                label: Text('${_multiSelectedIds.length}件を削除'),
              ),
            IconButton(
              tooltip: 'すべて展開',
              onPressed: _expandAll,
              icon: const Icon(Icons.unfold_more),
            ),
            IconButton(
              tooltip: 'すべて折りたたむ',
              onPressed: _collapseAll,
              icon: const Icon(Icons.unfold_less),
            ),
          ],
        ),
      );
}
