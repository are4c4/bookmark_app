import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../data/workspace_store.dart';
import '../services/bookmark_transfer_service.dart';
import '../services/profile_manager.dart';
import 'bookmark_lifecycle_page.dart';
import 'bookmark_unified_stage1_page.dart';
import 'collection_management_page.dart';
import 'global_search_page.dart';
import 'people_management_page.dart';
import 'photo_management_page.dart';
import 'profile_management_page.dart';
import 'tag_management_page.dart';

class BookmarkAppShell extends StatefulWidget {
  const BookmarkAppShell({
    super.key,
    required this.repository,
    required this.profileState,
    required this.onSwitchProfile,
    required this.onCreateProfile,
    required this.onRenameProfile,
    required this.onDuplicateProfile,
    required this.onDeleteProfile,
    required this.onSwitchWorkspace,
  });

  final BookmarkRepository repository;
  final ProfileState profileState;
  final Future<void> Function(DatabaseProfile profile) onSwitchProfile;
  final Future<void> Function(String name) onCreateProfile;
  final Future<void> Function(DatabaseProfile profile, String name) onRenameProfile;
  final Future<void> Function(DatabaseProfile profile) onDuplicateProfile;
  final Future<void> Function(DatabaseProfile profile) onDeleteProfile;
  final Future<void> Function(WorkspaceInfo workspace) onSwitchWorkspace;

  @override
  State<BookmarkAppShell> createState() => _BookmarkAppShellState();
}

class _BookmarkAppShellState extends State<BookmarkAppShell> {
  static const _transfer = BookmarkTransferService();
  static const _workspaceIcons = ['🏠', '📁', '📚', '🎬', '💻', '🧪', '⭐', '🗂️', '✍️', '🌱'];
  static const _workspaceColors = <int>[
    0xFF9B9A97,
    0xFF5B8DEF,
    0xFF5E9B76,
    0xFFD19A52,
    0xFFC56B6B,
    0xFF9876C9,
    0xFF4F9DA6,
    0xFFB07A91,
  ];

  var _index = 0;
  var _sidebarCollapsed = false;
  var _loadingWorkspaces = true;
  List<WorkspaceInfo> _workspaces = const [];

  @override
  void initState() {
    super.initState();
    _reloadWorkspaces();
  }

  @override
  void didUpdateWidget(covariant BookmarkAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _reloadWorkspaces();
  }

  Future<void> _reloadWorkspaces() async {
    final workspaces = await widget.repository.listWorkspaces();
    if (!mounted) return;
    setState(() {
      _workspaces = workspaces;
      _loadingWorkspaces = false;
    });
  }

  WorkspaceInfo? get _activeWorkspace {
    for (final workspace in _workspaces) {
      if (workspace.id == widget.repository.workspaceId) return workspace;
    }
    return _workspaces.isEmpty ? null : _workspaces.first;
  }

  Future<String?> _askName(String title, {String initial = '', String hint = ''}) async {
    var value = initial;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
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

  Future<void> _createWorkspace() async {
    final name = await _askName('Workspaceを追加', hint: '例: 修論');
    if (name?.isNotEmpty != true) return;
    try {
      final id = await widget.repository.createWorkspace(name!);
      await _reloadWorkspaces();
      final workspace = _workspaces.firstWhere((item) => item.id == id);
      await widget.onSwitchWorkspace(workspace);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Workspaceを作成できませんでした: $error')));
    }
  }

  Future<void> _editWorkspace(WorkspaceInfo workspace) async {
    var name = workspace.name;
    var icon = workspace.icon;
    var color = workspace.colorValue;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Workspaceを編集'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(initialValue: name, decoration: const InputDecoration(labelText: '名前'), onChanged: (value) => name = value),
              const SizedBox(height: 16),
              const Text('アイコン', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _workspaceIcons.map((value) => ChoiceChip(
                  label: Text(value, style: const TextStyle(fontSize: 18)),
                  selected: icon == value,
                  onSelected: (_) => setLocalState(() => icon = value),
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Text('色', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 9,
                children: _workspaceColors.map((value) => InkWell(
                  onTap: () => setLocalState(() => color = value),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color == value ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (saved != true || name.trim().isEmpty) return;
    await widget.repository.updateWorkspace(workspace, name: name, icon: icon, colorValue: color);
    await _reloadWorkspaces();
  }

  Future<void> _deleteWorkspace(WorkspaceInfo workspace) async {
    if (_workspaces.length <= 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「${workspace.name}」を削除しますか？'),
        content: const Text('中のブックマークと保存ビューは別のWorkspaceへ移動されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repository.deleteWorkspace(workspace);
    await _reloadWorkspaces();
    if (workspace.id == widget.repository.workspaceId && _workspaces.isNotEmpty) {
      await widget.onSwitchWorkspace(_workspaces.first);
    }
  }

  Future<void> _moveBookmark(int bookmarkId, WorkspaceInfo workspace) async {
    if (workspace.id == widget.repository.workspaceId) return;
    await widget.repository.moveBookmarksToWorkspace([bookmarkId], workspace);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「${workspace.name}」へ移動しました')));
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final updated = [..._workspaces];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _workspaces = updated);
    await widget.repository.reorderWorkspaces(updated.map((e) => e.id).toList());
  }

  Future<void> _handleProfileAction(String value) async {
    if (value == '__create__') {
      final name = await _askName('Profileを追加', hint: '例: 実験');
      if (name?.isNotEmpty == true) await widget.onCreateProfile(name!);
      return;
    }
    if (value == '__manage__') {
      setState(() => _index = 9);
      return;
    }
    final matches = widget.profileState.profiles.where((profile) => profile.id == value);
    if (matches.isNotEmpty) await widget.onSwitchProfile(matches.first);
  }

  Future<void> _handleDataAction(String value) async {
    try {
      if (value == 'export') {
        final path = await _transfer.exportJson(widget.repository);
        if (!mounted || path == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('バックアップを書き出しました: $path')));
      } else if (value == 'import') {
        final result = await _transfer.importFile(widget.repository);
        if (!mounted || result == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.imported}件を取り込みました（重複 ${result.skipped}件をスキップ）')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('データ操作に失敗しました: $error')));
    }
  }

  Widget _profileHeader() {
    final active = widget.profileState.activeProfile;
    return PopupMenuButton<String>(
      tooltip: 'Profileを切り替え',
      onSelected: _handleProfileAction,
      itemBuilder: (_) => [
        ...widget.profileState.profiles.map((profile) => PopupMenuItem(
          value: profile.id,
          child: Row(children: [
            Icon(profile.id == active.id ? Icons.check : Icons.circle_outlined, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(profile.name)),
          ]),
        )),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '__create__', child: Text('＋ Profileを追加')),
        const PopupMenuItem(value: '__manage__', child: Text('Profileを管理')),
      ],
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            const Icon(Icons.account_circle_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(active.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.keyboard_arrow_down, size: 17),
          ]),
        ),
      ),
    );
  }

  Widget _workspaceTile(WorkspaceInfo workspace, int index) {
    final scheme = Theme.of(context).colorScheme;
    final selected = workspace.id == widget.repository.workspaceId;
    final tile = Material(
      color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: selected ? null : () => widget.onSwitchWorkspace(workspace),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 2, top: 4, bottom: 4),
          child: Row(children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(Icons.drag_indicator, size: 14, color: scheme.onSurfaceVariant),
              ),
            ),
            Text(workspace.icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: Color(workspace.colorValue), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: Text(workspace.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
            PopupMenuButton<String>(
              tooltip: 'Workspace設定',
              iconSize: 16,
              onSelected: (value) {
                if (value == 'edit') _editWorkspace(workspace);
                if (value == 'delete') _deleteWorkspace(workspace);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('編集')),
                if (_workspaces.length > 1) const PopupMenuItem(value: 'delete', child: Text('削除')),
              ],
              icon: const Icon(Icons.more_horiz),
            ),
          ]),
        ),
      ),
    );

    return DragTarget<int>(
      key: ValueKey(workspace.id),
      onWillAcceptWithDetails: (_) => workspace.id != widget.repository.workspaceId,
      onAcceptWithDetails: (details) => _moveBookmark(details.data, workspace),
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: candidates.isNotEmpty ? Border.all(color: Color(workspace.colorValue), width: 1.5) : null,
        ),
        child: tile,
      ),
    );
  }

  Widget _workspaceList() {
    final scheme = Theme.of(context).colorScheme;
    if (_loadingWorkspaces) {
      return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 6, 4),
        child: Row(children: [
          Expanded(child: Text('WORKSPACES', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: .3))),
          IconButton(tooltip: 'Workspaceを追加', visualDensity: VisualDensity.compact, iconSize: 17, onPressed: _createWorkspace, icon: const Icon(Icons.add)),
        ]),
      ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _workspaces.length,
        onReorder: _reorder,
        itemBuilder: (context, index) => _workspaceTile(_workspaces[index], index),
      ),
    ]);
  }

  Widget _navTile(int index, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _index == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => setState(() => _index = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(children: [
              Icon(icon, size: 18, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
              const SizedBox(width: 9),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _subNavTile(int index, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _index == index;
    return Padding(
      padding: const EdgeInsets.only(left: 22, right: 6, top: 1, bottom: 1),
      child: Material(
        color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => setState(() => _index = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(children: [
              Icon(icon, size: 16, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _expandedSidebar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: 232,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 8, 4, 4),
            child: Row(children: [
              Expanded(child: _profileHeader()),
              IconButton(tooltip: 'サイドバーを閉じる', visualDensity: VisualDensity.compact, onPressed: () => setState(() => _sidebarCollapsed = true), icon: const Icon(Icons.keyboard_double_arrow_left, size: 17)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.only(bottom: 12), children: [
              _workspaceList(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 3),
                child: Text('LIBRARY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: .3)),
              ),
              _navTile(0, Icons.bookmarks_outlined, 'ブックマーク'),
              _subNavTile(2, Icons.inbox_outlined, '未整理'),
              _subNavTile(3, Icons.archive_outlined, 'アーカイブ'),
              _subNavTile(4, Icons.delete_outline, 'ゴミ箱'),
              const SizedBox(height: 3),
              _navTile(1, Icons.search, '全文検索'),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Divider(height: 1)),
              _navTile(5, Icons.photo_library_outlined, '写真'),
              _navTile(6, Icons.account_tree_outlined, 'タグ'),
              _navTile(7, Icons.people_outline, '人物'),
              _navTile(8, Icons.collections_bookmark_outlined, 'コレクション'),
              _navTile(9, Icons.manage_accounts_outlined, 'Profile管理'),
            ]),
          ),
          const Divider(height: 1),
          PopupMenuButton<String>(
            tooltip: 'データ',
            onSelected: _handleDataAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('インポート')),
              PopupMenuItem(value: 'export', child: Text('JSONバックアップ')),
            ],
            child: const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 10, 12),
              child: Row(children: [
                Icon(Icons.import_export, size: 17),
                SizedBox(width: 8),
                Text('データ', style: TextStyle(fontSize: 12.5)),
                Spacer(),
                Icon(Icons.more_horiz, size: 16),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _collapsedSidebar() {
    final scheme = Theme.of(context).colorScheme;
    final icons = [
      Icons.bookmarks_outlined,
      Icons.search,
      Icons.inbox_outlined,
      Icons.archive_outlined,
      Icons.delete_outline,
      Icons.photo_library_outlined,
      Icons.account_tree_outlined,
      Icons.people_outline,
      Icons.collections_bookmark_outlined,
      Icons.manage_accounts_outlined,
    ];
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: 48,
        child: Column(children: [
          const SizedBox(height: 8),
          IconButton(tooltip: 'サイドバーを開く', onPressed: () => setState(() => _sidebarCollapsed = false), icon: const Icon(Icons.keyboard_double_arrow_right, size: 18)),
          const SizedBox(height: 8),
          ...icons.asMap().entries.map((entry) => IconButton(
            onPressed: () => setState(() => _index = entry.key),
            style: IconButton.styleFrom(backgroundColor: _index == entry.key ? scheme.surfaceContainerHigh : Colors.transparent),
            icon: Icon(entry.value, size: 19),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _activeWorkspace;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(children: [
        _sidebarCollapsed ? _collapsedSidebar() : _expandedSidebar(),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        Expanded(
          child: IndexedStack(index: _index, children: [
            BookmarkUnifiedStage1Page(
              repository: widget.repository,
              profileName: widget.profileState.activeProfile.name,
              workspaceName: workspace?.name ?? 'Workspace',
            ),
            GlobalSearchPage(repository: widget.repository),
            BookmarkLifecyclePage.inbox(repository: widget.repository),
            BookmarkLifecyclePage.archive(repository: widget.repository),
            BookmarkLifecyclePage.trash(repository: widget.repository),
            PhotoManagementPage(repository: widget.repository),
            TagManagementPage(repository: widget.repository),
            PeopleManagementPage(repository: widget.repository),
            CollectionManagementPage(repository: widget.repository),
            ProfileManagementPage(
              state: widget.profileState,
              onSwitch: widget.onSwitchProfile,
              onCreate: widget.onCreateProfile,
              onRename: widget.onRenameProfile,
              onDuplicate: widget.onDuplicateProfile,
              onDelete: widget.onDeleteProfile,
            ),
          ]),
        ),
      ]),
    );
  }
}
