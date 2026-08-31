import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/bookmark_repository.dart';
import 'views/bookmark_details_page.dart';
import 'views/bookmark_workspace_page.dart';
import 'views/people_management_page.dart';
import 'views/photo_management_page.dart';
import 'views/tag_management_page.dart';

void main() {
  final database = AppDatabase();
  final repository = BookmarkRepository(database);

  runApp(BookmarkApp(repository: repository));
}

class BookmarkApp extends StatelessWidget {
  const BookmarkApp({
    super.key,
    required this.repository,
  });

  final BookmarkRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bookmark App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.bookmarks_outlined),
                selectedIcon: Icon(Icons.bookmarks),
                label: Text('ブックマーク'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('詳細'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: Text('写真'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_tree_outlined),
                selectedIcon: Icon(Icons.account_tree),
                label: Text('タグ管理'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('出演者'),
              ),
            ],
            onDestinationSelected: (index) => setState(() => _index = index),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                BookmarkWorkspacePage(repository: widget.repository),
                BookmarkDetailsPage(repository: widget.repository),
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
