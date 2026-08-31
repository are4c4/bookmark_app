import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/bookmark_repository.dart';
import 'services/bookmark_transfer_service.dart';
import 'services/profile_manager.dart';
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
  BookmarkRepository? _repository;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final manager = await ProfileManager.load();
      final database = AppDatabase(databaseName: manager.state.activeProfile.databaseName);
      if (!mounted) {
        await database.close();
        return;
      }
      setState(() {
        _profileManager = manager;
        _database = database;
        _repository = BookmarkRepository(database);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _switchProfile(DatabaseProfile profile) async {
    final manager = _profileManager;
    if (manager == null || manager.state.activeProfile.id == profile.id) return;
    await manager.setActiveProfile(profile);
    final oldDatabase = _database;
    final database = AppDatabase(databaseName: profile.databaseName);
    if (!mounted) {
      await database.close();
      return;
    }
    setState(() {
      _database = database;
      _repository = BookmarkRepository(database);
    });
    await oldDatabase?.close();
  }

  Future<void> _createProfile(String name) async {
    final manager = _profileManager;
    if (manager == null) return;
    final profile = await manager.createProfile(name);
    if (!mounted) return;
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('起動に失敗しました: $_error'))),
      );
    }

    final manager = _profileManager;
    final repository = _repository;
    if (manager == null || repository == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return BookmarkApp(
      repository: repository,
      profileState: manager.state,
      onSwitchProfile: _switchProfile,
      onCreateProfile: _createProfile,
      onRenameProfile: _renameProfile,
    );
  }
}

class BookmarkApp extends StatelessWidget {
  const BookmarkApp({
    super.key,
    required this.repository,
    required this.profileState,
    required this.onSwitchProfile,
    required this.onCreateProfile,
    required this.onRenameProfile,
  });

  final BookmarkRepository repository;
  final ProfileState profileState;
  final Future<void> Function(DatabaseProfile profile) onSwitchProfile;
  final Future<void> Function(String name) onCreateProfile;
  final Future<void> Function(DatabaseProfile profile, String name) onRenameProfile;

  @override
  Widget build(BuildContext context) {
    const notionText = Color(0xFF37352F);
    const notionMuted = Color(0xFF787774);
    const notionBorder = Color(0xFFE7E7E4);
    const notionSidebar = Color(0xFFF7F7F5);

    final scheme = ColorScheme.fromSeed(
      seedColor: notionText,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bookmark App',
      theme: ThemeData(
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
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: notionSidebar,
          indicatorColor: Color(0xFFEFEFED),
          selectedIconTheme: IconThemeData(color: notionText),
          unselectedIconTheme: IconThemeData(color: notionMuted),
          selectedLabelTextStyle: TextStyle(color: notionText, fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelTextStyle: TextStyle(color: notionMuted, fontSize: 12),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF1F1EF),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          labelStyle: const TextStyle(fontSize: 12.5, color: notionText),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: false,
          isDense: true,
          hintStyle: const TextStyle(color: Color(0xFF9B9A97)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: notionBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: notionBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: Color(0xFF9B9A97))),
        ),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: notionText)),
        iconTheme: const IconThemeData(color: notionText),
      ),
      home: BookmarkShell(
        key: ValueKey(profileState.activeProfile.id),
        repository: repository,
        profileState: profileState,
        onSwitchProfile: onSwitchProfile,
        onCreateProfile: onCreateProfile,
        onRenameProfile: onRenameProfile,
      ),
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
  });

  final BookmarkRepository repository;
  final ProfileState profileState;
  final Future<void> Function(DatabaseProfile profile) onSwitchProfile;
  final Future<void> Function(String name) onCreateProfile;
  final Future<void> Function(DatabaseProfile profile, String name) onRenameProfile;

  @override
  State<BookmarkShell> createState() => _BookmarkShellState();
}

class _BookmarkShellState extends State<BookmarkShell> {
  var _index = 0;
  static const _transfer = BookmarkTransferService();

  Future<void> _createProfileDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profileを追加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Profile名', hintText: '例: 実験'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('作成して切替'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name?.isNotEmpty == true) await widget.onCreateProfile(name!);
  }

  Future<void> _renameCurrentProfile() async {
    final profile = widget.profileState.activeProfile;
    final controller = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profile名を変更'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name?.isNotEmpty == true) await widget.onRenameProfile(profile, name!);
  }

  Future<void> _handleProfileAction(String value) async {
    if (value == '__create__') {
      await _createProfileDialog();
      return;
    }
    if (value == '__rename__') {
      await _renameCurrentProfile();
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
      }
      if (value == 'import') {
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

  @override
  Widget build(BuildContext context) {
    final activeProfile = widget.profileState.activeProfile;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: PopupMenuButton<String>(
                tooltip: 'Profileを切り替え',
                onSelected: _handleProfileAction,
                itemBuilder: (_) => [
                  ...widget.profileState.profiles.map(
                    (profile) => PopupMenuItem(
                      value: profile.id,
                      child: Row(
                        children: [
                          Icon(profile.id == activeProfile.id ? Icons.check : Icons.circle_outlined, size: 17),
                          const SizedBox(width: 8),
                          Expanded(child: Text(profile.name)),
                          if (profile.isDefault)
                            const Text('既存DB', style: TextStyle(fontSize: 11, color: Color(0xFF9B9A97))),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: '__create__', child: Text('＋ Profileを追加')),
                  const PopupMenuItem(value: '__rename__', child: Text('現在のProfile名を変更')),
                ],
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 25),
                      const SizedBox(height: 4),
                      Text(
                        activeProfile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.bookmarks_outlined), selectedIcon: Icon(Icons.bookmarks), label: Text('ブックマーク')),
              NavigationRailDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: Text('写真')),
              NavigationRailDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: Text('タグ管理')),
              NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('人物')),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PopupMenuButton<String>(
                    tooltip: 'インポート / エクスポート',
                    onSelected: _handleDataAction,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'import',
                        child: ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(Icons.file_download_outlined), title: Text('インポート')),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(Icons.file_upload_outlined), title: Text('JSONバックアップ')),
                      ),
                    ],
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.import_export, size: 22),
                        SizedBox(height: 4),
                        Text('データ', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            onDestinationSelected: (index) => setState(() => _index = index),
          ),
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
        ],
      ),
    );
  }
}
