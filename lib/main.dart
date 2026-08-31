import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/bookmark_repository.dart';
import 'views/bookmark_gallery_page.dart';

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
      home: BookmarkGalleryPage(repository: repository),
    );
  }
}
