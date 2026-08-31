import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/bookmark_repository.dart';
import 'data/workspace_store.dart';
import 'services/bookmark_transfer_service.dart';
import 'services/photo_storage_service.dart';
import 'services/profile_manager.dart';
import 'services/profile_storage_migrator.dart';
import 'views/bookmark_unified_stage1_page.dart';
import 'views/people_management_page.dart';
import 'views/photo_management_page.dart';
import 'views/tag_management_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BookmarkBootstrap());
}

class BookmarkBootstrap extends StatefulWidget {
  const BookmarkBootstrap({super.key});

  @override
  State<BookmarkBootstrap> createState() => _BookmarkBootstrapState();
}

class _BookmarkBootstrapState extends State<BookmarkBootstrap> {
  ProfileManager? _profileManager;
  AppDatabase? _database;
  WorkspaceStore? _workspaceStore;
  BookmarkRepository? _repository;
  Object? _error;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<BookmarkRepository> _openRepository(
    AppDatabase database,
    DatabaseProfile profile,
  ) async {
    await const ProfileStorageMigrator().migratePhotos(
      database: database,
      photoDirectoryPath: profile.photoDirectoryPath,
    );
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    _workspaceStore = workspaceStore;
    PhotoStorageService.activePhotoDirectoryPath = profile.photoDirectoryPath;
    return BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      workspaceId: workspaceId,
      profileDirectoryPath: profile.directoryPath,
    );
  }

  Future<void> _load() async {
    try {
      final manager = await ProfileManager.load();
      final profile = manager.state.activeProfile;
      final database = AppDatabase(databaseName: profile.databaseName);
      final repository = await _openRepository(database, profile);
      if (!mounted) {
        await database.close();
        return;
      }
      setState(() {
        _profileManager = manager;
        _database = database;
        _repository = repository;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _switchProfile(DatabaseProfile profile) async {
    final manager = _profileManager;
    if (manager == null || manager.state.activeProfile.id == profile.id || _switching) return;

    final previous = manager.state.activeProfile;
    final oldDatabase = _database;
    setState(() {
      _switching = true;
      _repository = null;
    });

    await WidgetsBinding.instance.endOfFrame;
    await oldDatabase?.close();
    _database = null;
    _workspaceStore = null;

    try {
      final database = AppDatabase(databaseName: profile.databaseName);
      final repository = await _openRepository(database, profile);
      await manager.setActiveProfile(profile);
      if (!mounted) {
        await database.close();
        return;
      }
      setState(() {
        _database = database;
        _repository = repository;
        _switching = false;
        _error = null;
      });
    } catch (error) {
      try {
        final fallbackDatabase = AppDatabase(databaseName: previous.databaseName);
        final fallbackRepository = await _openRepository(fallbackDatabase, previous);
        await manager.setActiveProfile(previous);
        if (!mounted) {
          await fallbackDatabase.close();
          return;
        }
        setState(() {
          _database = fallbackDatabase;
          _repository = fallbackRepository;
          _switching = false;
          _error = error;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _switching = false;
            _error = error;
          });
        }
      }
    }
  }

  Future<void> _switchWorkspace(WorkspaceInfo workspace) async {
    final store = _workspaceStore;
    final database = _database;
    final profile = _profileManager?.state.activeProfile;
    if (store == null || database == null || profile == null || _repository?.workspaceId == workspace.id) return;
    await store.setActiveWorkspace(workspace.id);
    if (!mounted) return;
    setState(() {
      _repository = BookmarkRepository(
        database,
        workspaceStore: store,
        workspaceId: workspace.id,
        profileDirectoryPath: profile.directoryPath,
      );
    });
  }

  Future<void> _createProfile(String name) async {
    final manager = _profileManager;
    if (manager == null) return;
    final profile = await manager.createProfile(name);
    await Future<void>.delayed(Duration.zero);
    await _switchProfile(profile);
  }

  Future<void> _renameProfile(DatabaseProfile profile, String name) async {
    final manager = _profileManager;
    if (manager == null) return;
    await manager.renameProfile(profile, name);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }

  ThemeData _theme() {
    const notionText = Color(0xFF37352F);
    const notionMuted = Color(0xFF787774);
    const notionBorder = Color(0xFFE7E7E4);
    const notionSidebar = Color(0xFFF7F7F5);
    final scheme = ColorScheme.fromSeed(
      seedColor: notionText,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: notionText,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: notionText,
        outline: notionBorder,
        outlineVariant: notionBorder,
        surfaceContainerLowest: notionSidebar,
        surfaceContainerLow: notionSidebar,
      ),
      scaffoldBackgroundColor: Colors.white,
      dividerColor: notionBorder,
      splashColor: const Color(0x0D000000),
      hoverColor: const Color(0x0A000000),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: notionBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: notionText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F1EF),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: const TextStyle(fontSize: 12.5, color: notionText),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        hintStyle: const TextStyle(color: Color(0xFF9B9A97)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: notionBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: notionBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: Color(0xFF9B9A97))),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: notionText)),
      iconTheme: const IconThemeData(color: notionText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = _profileManager;
    final repository = _repository;

    Widget home;
    if (_error != null && repository == null) {
      home = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('起動またはProfile切替に失敗しました:\n$_error'),
          ),
        ),
      );
    } else if (manager == null || repository == null || _switching) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else {
      home = BookmarkShell(
        key: ValueKey('${manager.state.activeProfile.id}:${repository.workspaceId}'),
        repository: repository,
        profileState: manager.state,
        onSwitchProfile: _switchProfile,
        onCreateProfile: _createProfile,
        onRenameProfile: _renameProfile,
        onSwitchWorkspace: _switchWorkspace,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bookmark App',
      theme: _theme(),
      home: home,
    );
  }
}

class BookmarkShell extends StatefulWidget {
  const BookmarkShell({
    super.key,
    required this.repository,
    required this.profileState,
    required this.onSwitchProfile,
    required this.onCreateProfile,
    required this.onRenameProfile,
    required this.onSwitchWorkspace,
  });

  final BookmarkRepository repository;
  final ProfileState profileState;
  final Future<void> Function(DatabaseProfile profile) onSwitchProfile;
  final Future<void> Function(String name) onCreateProfile;
  final Future<void> Function(DatabaseProfile profile, String name) onRenameProfile;
  final Future<void> Function(WorkspaceInfo workspace) onSwitchWorkspace;

  @override
  State<BookmarkShell> createState() => _BookmarkShellState();
}

class _BookmarkShellState extends State<BookmarkShell> {
  var _index = 0;
  bool _sidebarCollapsed = false;
  static const _transfer = BookmarkTransferService();

  Future<String?> _askName(String title, {String initial = '', String hint = ''}) async {
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
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, value.trim()), child: const Text('保存')),
        ],
      ),
    );
  }

  Future<void> _afterOverlayClosed() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _createProfileDialog() async {
    final name = await _askName('Profileを追加', hint: '例: 実験');
    if (name?.isNotEmpty != true) return;
    await _afterOverlayClosed();
    await widget.onCreateProfile(name!);
  }

  Future<void> _renameCurrentProfile() async {
    final profile = widget.profileState.activeProfile;
    final name = await _askName('Profile名を変更', initial: profile.name);
    if (name?.isNotEmpty != true) return;
    await _afterOverlayClosed();
    await widget.onRenameProfile(profile, name!);
  }

  Future<void> _handleProfileAction(String value) async {
    await _afterOverlayClosed();
    if (!mounted) return;
    if (value == '__create__') return _createProfileDialog();
    if (value == '__rename__') return _renameCurrentProfile();
    final matches = widget.profileState.profiles.where((profile) => profile.id == value);
    if (matches.isNotEmpty) await widget.onSwitchProfile(matches.first);
  }

  Future<void> _createWorkspace() async {
    final name = await _askName('Workspaceを追加', hint: '例: 修論');
    if (name?.isNotEmpty != true) return;
    await _afterOverlayClosed();
    try {
      final id = await widget.repository.createWorkspace(name!);
      final workspace = (await widget.repository.listWorkspaces()).firstWhere((item) => item.id == id);
      if (!mounted) return;
      await widget.onSwitchWorkspace(workspace);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Workspaceを作成できませんでした: $error')));
    }
  }

  Future<void> _renameWorkspace(WorkspaceInfo workspace) async {
    final name = await _askName('Workspace名を変更', initial: workspace.name);
    if (name?.isNotEmpty != true) return;
    await _afterOverlayClosed();
    await widget.repository.renameWorkspace(workspace, name!);
    if (mounted) setState(() {});
  }

  Future<void> _deleteWorkspace(WorkspaceInfo workspace) async {
    final workspaces = await widget.repository.listWorkspaces();
    if (workspaces.length <= 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「${workspace.name}」を削除しますか？'),
        content: const Text('中のブックマークと保存ビューは別のWorkspaceへ移動されます。人物・写真・タグは削除されません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok != true) return;
    await _afterOverlayClosed();
    try {
      await widget.repository.deleteWorkspace(workspace);
      final remaining = await widget.repository.listWorkspaces();
      if (!mounted) return;
      if (workspace.id == widget.repository.workspaceId) {
        await widget.onSwitchWorkspace(remaining.first);
      } else {
        setState(() {});
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Workspaceを削除できませんでした: $error')));
    }
  }

  Future<void> _workspaceActions(WorkspaceInfo workspace) async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(230, 140, 0, 0),
      items: const [
        PopupMenuItem(value: 'rename', child: Text('名前を変更')),
        PopupMenuItem(value: 'delete', child: Text('削除')),
      ],
    );
    if (selected == null) return;
    await _afterOverlayClosed();
    if (!mounted) return;
    if (selected == 'rename') await _renameWorkspace(workspace);
    if (selected == 'delete') await _deleteWorkspace(workspace);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.imported}件を取り込みました（重複 ${result.skipped}件をスキップ）')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('データ操作に失敗しました: $error')));
    }
  }

  Widget _profileHeader(DatabaseProfile activeProfile) {
    return PopupMenuButton<String>(
      tooltip: 'Profileを切り替え',
      onSelected: _handleProfileAction,
      itemBuilder: (_) => [
        ...widget.profileState.profiles.map(
          (profile) => PopupMenuItem(
            value: profile.id,
            child: Row(children: [
              Icon(profile.id == activeProfile.id ? Icons.check : Icons.circle_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(profile.name)),
            ]),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '__create__', child: Text('＋ Profileを追加')),
        const PopupMenuItem(value: '__rename__', child: Text('現在のProfile名を変更')),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          const Icon(Icons.account_circle_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(activeProfile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 17),
        ]),
      ),
    );
  }

  Widget _pageTile(int index, IconData icon, String label) {
    final selected = _index == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: selected ? const Color(0xFFEFEFED) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => setState(() => _index = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(children: [
              Icon(icon, size: 18, color: selected ? const Color(0xFF37352F) : const Color(0xFF787774)),
              const SizedBox(width: 9),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _workspaceList() {
    return FutureBuilder<List<WorkspaceInfo>>(
      future: widget.repository.listWorkspaces(),
      builder: (context, snapshot) {
        final workspaces = snapshot.data ?? const <WorkspaceInfo>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 6, 4),
              child: Row(children: [
                const Expanded(
                  child: Text(
                    'WORKSPACES',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF9B9A97), letterSpacing: .3),
                  ),
                ),
                IconButton(
                  tooltip: 'Workspaceを追加',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  onPressed: _createWorkspace,
                  icon: const Icon(Icons.add),
                ),
              ]),
            ),
            ...workspaces.map((workspace) {
              final selected = workspace.id == widget.repository.workspaceId;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Material(
                  color: selected ? const Color(0xFFEFEFED) : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: selected ? null : () => widget.onSwitchWorkspace(workspace),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 9, right: 2, top: 5, bottom: 5),
                      child: Row(children: [
                        Icon(selected ? Icons.space_dashboard : Icons.space_dashboard_outlined, size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            workspace.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Workspaceの設定',
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          onPressed: () => _workspaceActions(workspace),
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: TextButton.icon(
                style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7)),
                onPressed: _createWorkspace,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('新しいWorkspace', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dataMenu() {
    return PopupMenuButton<String>(
      tooltip: 'データ',
      onSelected: _handleDataAction,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.file_download_outlined, size: 18), SizedBox(width: 8), Text('インポート')])),
        PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.file_upload_outlined, size: 18), SizedBox(width: 8), Text('JSONバックアップ')])),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Icon(Icons.import_export, size: 17),
          SizedBox(width: 8),
          Text('データ', style: TextStyle(fontSize: 12.5)),
          Spacer(),
          Icon(Icons.more_horiz, size: 16),
        ]),
      ),
    );
  }

  Widget _expandedSidebar(DatabaseProfile activeProfile) {
    return Container(
      width: 224,
      color: const Color(0xFFF7F7F5),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(7, 8, 4, 4),
          child: Row(children: [
            Expanded(child: _profileHeader(activeProfile)),
            IconButton(
              tooltip: 'サイドバーを閉じる',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _sidebarCollapsed = true),
              icon: const Icon(Icons.keyboard_double_arrow_left, size: 17),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              _workspaceList(),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Divider(height: 1)),
              _pageTile(0, Icons.bookmarks_outlined, 'ブックマーク'),
              _pageTile(1, Icons.photo_library_outlined, '写真'),
              _pageTile(2, Icons.account_tree_outlined, 'タグ'),
              _pageTile(3, Icons.people_outline, '人物'),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 8), child: _dataMenu()),
      ]),
    );
  }

  Widget _collapsedSidebar() {
    const icons = [Icons.bookmarks_outlined, Icons.photo_library_outlined, Icons.account_tree_outlined, Icons.people_outline];
    return Container(
      width: 48,
      color: const Color(0xFFF7F7F5),
      child: Column(children: [
        const SizedBox(height: 8),
        IconButton(
          tooltip: 'サイドバーを開く',
          onPressed: () => setState(() => _sidebarCollapsed = false),
          icon: const Icon(Icons.keyboard_double_arrow_right, size: 18),
        ),
        const SizedBox(height: 8),
        ...List.generate(icons.length, (index) => IconButton(
              tooltip: const ['ブックマーク', '写真', 'タグ', '人物'][index],
              onPressed: () => setState(() => _index = index),
              icon: Icon(icons[index], size: 20),
            )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = widget.profileState.activeProfile;
    return Scaffold(
      body: Row(children: [
        _sidebarCollapsed ? _collapsedSidebar() : _expandedSidebar(activeProfile),
        const VerticalDivider(width: 1, color: Color(0xFFE7E7E4)),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              BookmarkUnifiedStage1Page(repository: widget.repository),
              PhotoManagementPage(repository: widget.repository),
              TagManagementPage(repository: widget.repository),
              PeopleManagementPage(repository: widget.repository),
            ],
          ),
        ),
      ]),
    );
  }
}
