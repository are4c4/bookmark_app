import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/bookmark_repository.dart';
import 'services/bookmark_transfer_service.dart';
import 'views/bookmark_unified_page.dart';
import 'views/people_management_page.dart';
import 'views/photo_management_page.dart';
import 'views/tag_management_page.dart';

void main() {
  final database = AppDatabase();
  final repository = BookmarkRepository(database);

  runApp(BookmarkApp(repository: repository));
}

class BookmarkApp extends StatelessWidget {
  const BookmarkApp({super.key, required this.repository});

  final BookmarkRepository repository;

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
      home: BookmarkShell(repository: repository),
    );
  }
}

class BookmarkShell extends StatefulWidget {
  const BookmarkShell({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<BookmarkShell> createState() => _BookmarkShellState();
}

class _BookmarkShellState extends State<BookmarkShell> {
  var _index = 0;
  static const _transfer = BookmarkTransferService();

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
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.bookmarks_outlined), selectedIcon: Icon(Icons.bookmarks), label: Text('ブックマーク')),
              NavigationRailDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: Text('写真')),
              NavigationRailDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: Text('タグ管理')),
              NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('出演者')),
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
                BookmarkUnifiedPage(repository: widget.repository),
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
