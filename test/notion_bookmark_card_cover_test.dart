import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/widgets/notion_bookmark_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Gallery card renders the supplied canonical cover widget',
      (tester) async {
    final bookmark = BookmarkItem(
      id: 1,
      url: 'https://example.com/article',
      title: 'Article',
      createdAt: DateTime(2026, 9, 4),
      favorite: false,
      status: 'unread',
      rating: 0,
      openCount: 0,
      tags: const [],
      people: const [],
      photos: const [],
      collections: const [],
      thumbnail: 'https://example.com/legacy.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotionBookmarkCard(
            bookmark: bookmark,
            selected: false,
            showImage: true,
            showUrl: false,
            showTags: false,
            showPeople: false,
            showDescription: false,
            showCreatedAt: false,
            showFavorite: false,
            showStatus: false,
            showRating: false,
            showHistory: false,
            onTap: () {},
            onToggleFavorite: () {},
            menu: const SizedBox.shrink(),
            cover: const SizedBox(
              height: 80,
              child: Center(child: Text('managed-cover')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('managed-cover'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
