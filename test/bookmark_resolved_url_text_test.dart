import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/bookmark_url_resolver.dart';
import 'package:bookmark_app/widgets/bookmark_resolved_url_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BookmarkItem bookmark({String url = 'https://legacy.example/stale'}) =>
      BookmarkItem(
        id: 1,
        url: url,
        title: 'Example',
        createdAt: DateTime(2026, 9, 6),
        favorite: false,
        status: 'unread',
        rating: 0,
        openCount: 0,
        tags: const [],
        people: const [],
        photos: const [],
        collections: const [],
      );

  testWidgets('renders canonical Weblink URL and can compact it to domain',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookmarkResolvedUrlText(
            bookmark: bookmark(),
            compact: true,
            resolveUrl: (_) async => const BookmarkUrlSource(
              kind: BookmarkUrlSourceKind.canonicalWeblink,
              value: 'https://www.canonical.example/article',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('canonical.example'), findsOneWidget);
    expect(find.textContaining('legacy.example'), findsNothing);
  });

  testWidgets('keeps legacy Bookmark URL as compatibility fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookmarkResolvedUrlText(
            bookmark: bookmark(url: 'https://legacy.example/fallback'),
            resolveUrl: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('https://legacy.example/fallback'), findsOneWidget);
  });
}
