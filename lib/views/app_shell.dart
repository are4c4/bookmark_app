import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bookmark_repository.dart';
import '../data/workspace_store.dart';
import '../services/bookmark_transfer_service.dart';
import '../services/profile_manager.dart';
import '../services/profile_backup_service.dart';
import '../ui/ui_tokens.dart';
import 'bookmark_lifecycle_page.dart';
import 'bookmark_unified_stage1_page.dart';
import 'collection_management_page.dart';
import 'global_search_page.dart';
import 'people_management_page.dart';
import 'photo_management_page.dart';
import 'profile_management_page.dart';
import 'settings_page.dart';
import 'tag_management_page.dart';

class BookmarkAppShell extends StatefulWidget {
  const BookmarkAppShell({
    super.key,
    required this.repository,
    required this.profileState,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onSwitchProfile,
    required this.onCreateProfile,
    required this.onRenameProfile,
    required this.onDuplicateProfile,
    required this.onImportProfileBackup,
    required this.onDeleteProfile,
    required this.onSwitchWorkspace,
  });

  final BookmarkRepository repository;
  final ProfileState profileState;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<void> Function(DatabaseProfile profile) onSwitchProfile;
  final Future<void> Function(String name) onCreateProfile;
  final Future<void> Function(DatabaseProfile profile, String name) onRenameProfile;
  final Future<void> Function(DatabaseProfile profile) onDuplicateProfile;
  final Future<void> Function(String archivePath, String name)
      onImportProfileBackup;
  final Future<void> Function(DatabaseProfile profile) onDeleteProfile;
  final Future<void> Function(WorkspaceInfo workspace) onSwitchWorkspace;

  @override
  State<BookmarkAppShell> createState() => _BookmarkAppShellState();
}

class _BookmarkAppShellState extends State<BookmarkAppShell> {
  static const _transfer = BookmarkTransferService();
  static const _profileBackup = ProfileBackupService();
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
  final Map<int, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    _reloadWorkspaces();
  }

  @override
  void didUpdateWidget(covariant BookmarkAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _pageCache.clear();
      _reloadWorkspaces();
    } else if (oldWidget.profileState != widget.profileState ||
        oldWidget.themeMode != widget.themeMode) {
      _pageCache.remove(9);
      _pageCache.remove(10);
    }
  }

  Future<void> _reloadWorkspaces() async {
    final workspaces = await widget.repository.listWorkspaces();
    if (!mounted) return;
    setState(() {
      _pageCache.remove(0);
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
              const SizedBox(height: UiTokens.space16),
              const Text('アイコン', style: TextStyle(fontSize: UiTokens.textSm, fontWeight: FontWeight.w600)),
              const SizedBox(height: UiTokens.space6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _workspaceIcons.map((value) => ChoiceChip(
                  label: Text(value, style: const TextStyle(fontSize: UiTokens.iconNormal)),
                  selected: icon == value,
                  onSelected: (_) => setLocalState(() => icon = value),
                )).toList(),
              ),
              const SizedBox(height: UiTokens.space16),
              const Text('色', style: TextStyle(fontSize: UiTokens.textSm, fontWeight: FontWeight.w600)),
              const SizedBox(height: UiTokens.space6),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ブックマークを書き出しました: $path')));
      } else if (value == 'import') {
        final result = await _transfer.importFile(widget.repository);
        if (!mounted || result == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.imported}件を取り込みました（重複 ${result.skipped}件をスキップ）')));
      } else if (value == 'profile_export') {
        final active = widget.profileState.activeProfile;
        final path = await _profileBackup.exportProfile(
          profileName: active.name,
          profileDirectoryPath: active.directoryPath,
          database: widget.repository.lifecycleStore.database,
        );
        if (!mounted || path == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profileバックアップを保存しました: $path')),
        );
      } else if (value == 'profile_import') {
        final archivePath = await _profileBackup.pickBackupFile();
        if (!mounted || archivePath == null) return;
        final name = await _askName(
          '復元するProfile名',
          initial: '復元したProfile',
        );
        if (name?.isNotEmpty != true) return;
        await widget.onImportProfileBackup(archivePath, name!);
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
            Icon(profile.id == active.id ? Icons.check : Icons.circle_outlined, size: UiTokens.iconSmall),
            const SizedBox(width: UiTokens.space8),
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
          padding: const EdgeInsets.symmetric(horizontal: UiTokens.space8),
          child: Row(children: [
            const Icon(Icons.account_circle_outlined, size: UiTokens.iconLarge),
            const SizedBox(width: UiTokens.space8),
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
      borderRadius: BorderRadius.circular(UiTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(UiTokens.radiusSm),
        onTap: selected ? null : () => widget.onSwitchWorkspace(workspace),
        child: SizedBox(
          height: UiTokens.sidebarRowHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: UiTokens.space8, right: UiTokens.space2),
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
              const SizedBox(width: UiTokens.space6),
              Expanded(child: Text(workspace.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
              PopupMenuButton<String>(
                tooltip: 'Workspace設定',
                iconSize: UiTokens.iconSmall,
                padding: EdgeInsets.zero,
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
      ),
    );

    return DragTarget<int>(
      key: ValueKey(workspace.id),
      onWillAcceptWithDetails: (_) => workspace.id != widget.repository.workspaceId,
      onAcceptWithDetails: (details) => _moveBookmark(details.data, workspace),
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(horizontal: UiTokens.space6, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UiTokens.radiusSm),
          border: candidates.isNotEmpty ? Border.all(color: Color(workspace.colorValue), width: 1.5) : null,
        ),
        child: tile,
      ),
    );
  }

  Widget _sectionHeader(String label, {VoidCallback? onAdd, String? tooltip}) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: UiTokens.sidebarSectionHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: UiTokens.space12, right: UiTokens.space6),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: UiTokens.textXs, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: .3))),
          if (onAdd != null)
            IconButton(
              tooltip: tooltip,
              visualDensity: VisualDensity.compact,
              iconSize: 17,
              padding: EdgeInsets.zero,
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
        ]),
      ),
    );
  }

  Widget _workspaceList() {
    if (_loadingWorkspaces) {
      return const Padding(padding: EdgeInsets.all(UiTokens.space16), child: LinearProgressIndicator());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionHeader('WORKSPACES', onAdd: _createWorkspace, tooltip: 'Workspaceを追加'),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _workspaces.length,
        onReorderItem: _reorder,
        itemBuilder: (context, index) => _workspaceTile(_workspaces[index], index),
      ),
    ]);
  }

  Widget _navTile(int index, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _index == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UiTokens.space6, vertical: 1),
      child: Material(
        color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(UiTokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(UiTokens.radiusSm),
          onTap: () => setState(() => _index = index),
          child: SizedBox(
            height: UiTokens.sidebarRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(children: [
                Icon(icon, size: UiTokens.iconNormal, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
                const SizedBox(width: 9),
                Text(label, style: TextStyle(fontSize: UiTokens.textMd, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _subNavTile(int index, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _index == index;
    return Padding(
      padding: const EdgeInsets.only(left: 22, right: UiTokens.space6, top: 1, bottom: 1),
      child: Material(
        color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(UiTokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(UiTokens.radiusSm),
          onTap: () => setState(() => _index = index),
          child: SizedBox(
            height: UiTokens.sidebarChildRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(children: [
                Icon(icon, size: UiTokens.iconSmall, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
                const SizedBox(width: UiTokens.space8),
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
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
        width: UiTokens.sidebarWidth,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(7, UiTokens.space8, UiTokens.space4, UiTokens.space4),
            child: Row(children: [
              Expanded(child: _profileHeader()),
              IconButton(tooltip: 'サイドバーを閉じる', visualDensity: VisualDensity.compact, onPressed: () => setState(() => _sidebarCollapsed = true), icon: const Icon(Icons.keyboard_double_arrow_left, size: 17)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.only(bottom: UiTokens.space12), children: [
              _workspaceList(),
              const SizedBox(height: UiTokens.space6),
              _sectionHeader('LIBRARY'),
              _navTile(0, Icons.bookmarks_outlined, 'ブックマーク'),
              _subNavTile(2, Icons.inbox_outlined, '未整理'),
              _subNavTile(3, Icons.archive_outlined, 'アーカイブ'),
              _subNavTile(4, Icons.delete_outline, 'ゴミ箱'),
              const SizedBox(height: UiTokens.space4),
              _navTile(1, Icons.search, '全文検索'),
              const Padding(padding: EdgeInsets.symmetric(horizontal: UiTokens.space12, vertical: UiTokens.space6), child: Divider(height: 1)),
              _navTile(5, Icons.photo_library_outlined, '写真'),
              _navTile(6, Icons.account_tree_outlined, 'タグ'),
              _navTile(7, Icons.people_outline, '人物'),
              _navTile(8, Icons.collections_bookmark_outlined, 'コレクション'),
              _navTile(9, Icons.manage_accounts_outlined, 'Profile管理'),
              _navTile(10, Icons.settings_outlined, '設定'),
            ]),
          ),
          const Divider(height: 1),
          PopupMenuButton<String>(
            tooltip: 'データ',
            onSelected: _handleDataAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('ブックマークをインポート')),
              PopupMenuItem(value: 'export', child: Text('ブックマークをJSON書き出し')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'profile_export',
                child: Text('Profileを完全バックアップ'),
              ),
              PopupMenuItem(
                value: 'profile_import',
                child: Text('バックアップからProfileを復元'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 10, 12),
              child: Row(children: [
                Icon(Icons.import_export, size: 17),
                SizedBox(width: UiTokens.space8),
                Text('データ', style: TextStyle(fontSize: 12.5)),
                Spacer(),
                Icon(Icons.more_horiz, size: UiTokens.iconSmall),
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
      Icons.settings_outlined,
    ];
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: UiTokens.collapsedSidebarWidth,
        child: Column(children: [
          const SizedBox(height: UiTokens.space8),
          IconButton(tooltip: 'サイドバーを開く', onPressed: () => setState(() => _sidebarCollapsed = false), icon: const Icon(Icons.keyboard_double_arrow_right, size: UiTokens.iconNormal)),
          const SizedBox(height: UiTokens.space8),
          ...icons.asMap().entries.map((entry) => IconButton(
            onPressed: () => setState(() => _index = entry.key),
            style: IconButton.styleFrom(backgroundColor: _index == entry.key ? scheme.surfaceContainerHigh : Colors.transparent),
            icon: Icon(entry.value, size: 19),
          )),
        ]),
      ),
    );
  }

  Future<void> _showCommandPalette() async {
    var query = '';
    const destinations = <(String, IconData, int)>[
      ('ブックマーク', Icons.bookmarks_outlined, 0),
      ('全文検索', Icons.search, 1),
      ('未整理', Icons.inbox_outlined, 2),
      ('アーカイブ', Icons.archive_outlined, 3),
      ('ゴミ箱', Icons.delete_outline, 4),
      ('写真', Icons.photo_library_outlined, 5),
      ('タグ', Icons.account_tree_outlined, 6),
      ('人物', Icons.people_outline, 7),
      ('コレクション', Icons.collections_bookmark_outlined, 8),
      ('Profile管理', Icons.manage_accounts_outlined, 9),
      ('設定', Icons.settings_outlined, 10),
    ];

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final normalized = query.trim().toLowerCase();
          final visible = destinations
              .where(
                (destination) =>
                    normalized.isEmpty ||
                    destination.$1.toLowerCase().contains(normalized),
              )
              .toList();
          return AlertDialog(
            title: const Text('コマンドパレット'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '移動先を検索',
                    ),
                    onChanged: (value) =>
                        setLocalState(() => query = value),
                  ),
                  const SizedBox(height: UiTokens.space8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final destination = visible[index];
                        return ListTile(
                          leading: Icon(
                            destination.$2,
                            size: UiTokens.iconNormal,
                          ),
                          title: Text(destination.$1),
                          trailing: const Icon(
                            Icons.keyboard_return,
                            size: UiTokens.iconSmall,
                          ),
                          onTap: () =>
                              Navigator.pop(dialogContext, destination.$3),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected != null && mounted) {
      setState(() => _index = selected);
    }
  }

  Widget _buildPage(int index, WorkspaceInfo? workspace) => switch (index) {
        0 => BookmarkUnifiedStage1Page(
            repository: widget.repository,
            profileName: widget.profileState.activeProfile.name,
            workspaceName: workspace?.name ?? 'Workspace',
          ),
        1 => GlobalSearchPage(repository: widget.repository),
        2 => BookmarkLifecyclePage.inbox(repository: widget.repository),
        3 => BookmarkLifecyclePage.archive(repository: widget.repository),
        4 => BookmarkLifecyclePage.trash(repository: widget.repository),
        5 => PhotoManagementPage(repository: widget.repository),
        6 => TagManagementPage(repository: widget.repository),
        7 => PeopleManagementPage(repository: widget.repository),
        8 => CollectionManagementPage(repository: widget.repository),
        9 => ProfileManagementPage(
            state: widget.profileState,
            onSwitch: widget.onSwitchProfile,
            onCreate: widget.onCreateProfile,
            onRename: widget.onRenameProfile,
            onDuplicate: widget.onDuplicateProfile,
            onDelete: widget.onDeleteProfile,
          ),
        _ => SettingsPage(
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
      };

  List<Widget> _lazyPages(WorkspaceInfo? workspace) {
    _pageCache.putIfAbsent(_index, () => _buildPage(_index, workspace));
    return List<Widget>.generate(
      11,
      (index) => _pageCache[index] ?? const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _activeWorkspace;
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyK,
          meta: true,
        ): _showCommandPalette,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(children: [
            _sidebarCollapsed ? _collapsedSidebar() : _expandedSidebar(),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: _lazyPages(workspace),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
