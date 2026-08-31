import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/bookmark_lifecycle_store.dart';
import 'data/bookmark_repository.dart';
import 'data/workspace_store.dart';
import 'services/photo_storage_service.dart';
import 'services/profile_manager.dart';
import 'services/profile_storage_migrator.dart';
import 'views/app_shell.dart';
import 'widgets/global_file_drop_layer.dart';

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
  BookmarkLifecycleStore? _lifecycleStore;
  BookmarkRepository? _repository;
  Object? _error;
  bool _switching = false;
  ThemeMode _themeMode = ThemeMode.system;

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
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    _workspaceStore = workspaceStore;
    _lifecycleStore = lifecycleStore;
    PhotoStorageService.activePhotoDirectoryPath = profile.photoDirectoryPath;
    return BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
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
        await _lifecycleStore?.dispose();
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
    if (manager == null ||
        manager.state.activeProfile.id == profile.id ||
        _switching) {
      return;
    }
    final previous = manager.state.activeProfile;
    final oldDatabase = _database;
    final oldLifecycle = _lifecycleStore;
    setState(() {
      _switching = true;
      _repository = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    await oldLifecycle?.dispose();
    await oldDatabase?.close();
    _database = null;
    _workspaceStore = null;
    _lifecycleStore = null;
    try {
      final database = AppDatabase(databaseName: profile.databaseName);
      final repository = await _openRepository(database, profile);
      await manager.setActiveProfile(profile);
      if (!mounted) {
        await _lifecycleStore?.dispose();
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
        final fallbackRepository =
            await _openRepository(fallbackDatabase, previous);
        await manager.setActiveProfile(previous);
        if (!mounted) {
          await _lifecycleStore?.dispose();
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
    final lifecycle = _lifecycleStore;
    final database = _database;
    final profile = _profileManager?.state.activeProfile;
    if (store == null ||
        lifecycle == null ||
        database == null ||
        profile == null ||
        _repository?.workspaceId == workspace.id) {
      return;
    }
    await store.setActiveWorkspace(workspace.id);
    if (!mounted) return;
    setState(() {
      _repository = BookmarkRepository(
        database,
        workspaceStore: store,
        lifecycleStore: lifecycle,
        workspaceId: workspace.id,
        profileDirectoryPath: profile.directoryPath,
      );
    });
  }

  Future<void> _createProfile(String name) async {
    final manager = _profileManager;
    if (manager == null) return;
    final profile = await manager.createProfile(name);
    if (mounted) setState(() {});
    await Future<void>.delayed(Duration.zero);
    await _switchProfile(profile);
  }

  Future<void> _renameProfile(DatabaseProfile profile, String name) async {
    final manager = _profileManager;
    if (manager == null) return;
    await manager.renameProfile(profile, name);
    if (mounted) setState(() {});
  }

  Future<void> _duplicateProfile(DatabaseProfile profile) async {
    final manager = _profileManager;
    if (manager == null) return;
    try {
      if (manager.state.activeProfile.id == profile.id) {
        await _database?.customStatement('PRAGMA wal_checkpoint(FULL)');
      }
      await manager.duplicateProfile(profile);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _deleteProfile(DatabaseProfile profile) async {
    final manager = _profileManager;
    if (manager == null) return;
    try {
      await manager.deleteProfile(profile);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _lifecycleStore?.dispose();
    _database?.close();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final notionText = dark ? const Color(0xFFE7E7E5) : const Color(0xFF37352F);
    final notionMuted = dark ? const Color(0xFFA9A9A6) : const Color(0xFF787774);
    final notionBorder = dark ? const Color(0xFF3B3B39) : const Color(0xFFE7E7E4);
    final notionSurface = dark ? const Color(0xFF191919) : Colors.white;
    final notionSidebar = dark ? const Color(0xFF202020) : const Color(0xFFF7F7F5);
    final notionRaised = dark ? const Color(0xFF2A2A28) : const Color(0xFFF1F1EF);
    final selectedTile = dark ? const Color(0xFF343432) : const Color(0xFFE9E9E6);
    final scheme = ColorScheme.fromSeed(
      seedColor: notionText,
      brightness: brightness,
      surface: notionSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme.copyWith(
        primary: notionText,
        onPrimary: notionSurface,
        surface: notionSurface,
        onSurface: notionText,
        onSurfaceVariant: notionMuted,
        outline: notionBorder,
        outlineVariant: notionBorder,
        surfaceContainerLowest: notionSidebar,
        surfaceContainerLow: notionSidebar,
        surfaceContainer: notionRaised,
        surfaceContainerHigh: notionRaised,
        surfaceContainerHighest: notionRaised,
      ),
      scaffoldBackgroundColor: notionSurface,
      dividerColor: notionBorder,
      splashColor: dark ? const Color(0x18FFFFFF) : const Color(0x0D000000),
      hoverColor: dark ? const Color(0x12FFFFFF) : const Color(0x0A000000),
      listTileTheme: ListTileThemeData(
        minTileHeight: 36,
        minVerticalPadding: 0,
        horizontalTitleGap: 8,
        selectedTileColor: selectedTile,
        selectedColor: notionText,
        iconColor: notionMuted,
        textColor: notionText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: notionSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: notionBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: notionSurface,
        foregroundColor: notionText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: notionRaised,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: TextStyle(fontSize: 12.5, color: notionText),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        hintStyle: TextStyle(color: notionMuted),
        filled: dark,
        fillColor: dark ? const Color(0xFF242424) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: notionBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: notionBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: notionMuted),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: notionText),
      ),
      iconTheme: IconThemeData(color: notionText),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? const Color(0xFF252525) : Colors.white,
      ),
      dialogTheme: DialogThemeData(backgroundColor: notionSurface),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'システム',
        ThemeMode.light => 'ライト',
        ThemeMode.dark => 'ダーク',
      };

  ThemeMode _nextThemeMode() => switch (_themeMode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      };

  IconData _themeIcon() => switch (_themeMode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

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
      home = GlobalFileDropLayer(
        repository: repository,
        child: BookmarkAppShell(
          key: ValueKey('${manager.state.activeProfile.id}:${repository.workspaceId}'),
          repository: repository,
          profileState: manager.state,
          onSwitchProfile: _switchProfile,
          onCreateProfile: _createProfile,
          onRenameProfile: _renameProfile,
          onDuplicateProfile: _duplicateProfile,
          onDeleteProfile: _deleteProfile,
          onSwitchWorkspace: _switchWorkspace,
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bookmark App',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      builder: (context, child) => Stack(
        children: [
          Positioned.fill(child: child ?? const SizedBox.shrink()),
          Positioned(
            left: 8,
            bottom: 8,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(7),
              elevation: 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => setState(() => _themeMode = _nextThemeMode()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_themeIcon(), size: 17),
                      const SizedBox(width: 7),
                      Text(
                        _themeLabel(_themeMode),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      home: home,
    );
  }
}
