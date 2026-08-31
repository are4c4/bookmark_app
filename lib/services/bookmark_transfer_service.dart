import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:html/parser.dart' as html_parser;

import '../data/bookmark_repository.dart';

class BookmarkTransferResult {
  const BookmarkTransferResult({required this.imported, required this.skipped});
  final int imported;
  final int skipped;
}

class BookmarkTransferService {
  const BookmarkTransferService();

  Future<String?> exportJson(BookmarkRepository repository) async {
    final bookmarks = await repository.watchAll().first;
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'bookmarks': bookmarks
          .map((bookmark) => {
                'url': bookmark.url,
                'title': bookmark.title,
                'thumbnail': bookmark.thumbnail,
                'description': bookmark.description,
                'favorite': bookmark.favorite,
                'status': bookmark.status,
                'rating': bookmark.rating,
                'tags': bookmark.tags.map((tag) => tag.name).toList(),
                'people': bookmark.people.map((person) => person.name).toList(),
                'collections': bookmark.collections.map((collection) => collection.name).toList(),
              })
          .toList(),
    };

    final location = await getSaveLocation(
      suggestedName: 'bookmark_backup_${DateTime.now().toIso8601String().substring(0, 10)}.json',
      acceptedTypeGroups: const [XTypeGroup(label: 'JSON', extensions: ['json'])],
    );
    if (location == null) return null;
    await File(location.path).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return location.path;
  }

  Future<BookmarkTransferResult?> importFile(BookmarkRepository repository) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Bookmark files', extensions: ['json', 'html', 'htm']),
      ],
    );
    if (file == null) return null;
    final extension = file.name.toLowerCase().split('.').last;
    final text = await File(file.path).readAsString();
    if (extension == 'json') return _importJson(repository, text);
    return _importHtml(repository, text);
  }

  Future<BookmarkTransferResult> _importJson(BookmarkRepository repository, String text) async {
    final decoded = jsonDecode(text);
    final list = decoded is Map<String, dynamic> ? decoded['bookmarks'] : null;
    if (list is! List) throw const FormatException('bookmarks 配列がありません');
    var imported = 0;
    var skipped = 0;

    for (final raw in list) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final url = (map['url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      if (await repository.findDuplicateUrl(url) != null) {
        skipped++;
        continue;
      }
      final id = await repository.create(
        url: url,
        title: (map['title'] ?? url).toString(),
        thumbnail: map['thumbnail']?.toString(),
        description: map['description']?.toString(),
        favorite: map['favorite'] == true,
        status: (map['status'] ?? 'unread').toString(),
        rating: int.tryParse('${map['rating'] ?? 0}') ?? 0,
        tagNames: (map['tags'] is List ? map['tags'] as List : const []).map((e) => e.toString()),
        personNames: (map['people'] is List ? map['people'] as List : const []).map((e) => e.toString()),
      );
      final collections = (map['collections'] is List ? map['collections'] as List : const []).map((e) => e.toString()).toList();
      if (collections.isNotEmpty) {
        final item = (await repository.watchAll().first).where((bookmark) => bookmark.id == id).firstOrNull;
        if (item != null) {
          final existing = await repository.watchCollections().first;
          for (final name in collections) {
            if (!existing.any((collection) => collection.name.toLowerCase() == name.toLowerCase())) {
              await repository.createCollection(name);
            }
          }
          final refreshed = await repository.watchCollections().first;
          await repository.setBookmarkCollections(
            item,
            refreshed.where((collection) => collections.any((name) => name.toLowerCase() == collection.name.toLowerCase())),
          );
        }
      }
      imported++;
    }
    return BookmarkTransferResult(imported: imported, skipped: skipped);
  }

  Future<BookmarkTransferResult> _importHtml(BookmarkRepository repository, String text) async {
    final document = html_parser.parse(text);
    final links = document.querySelectorAll('a[href]');
    var imported = 0;
    var skipped = 0;
    for (final link in links) {
      final url = link.attributes['href']?.trim() ?? '';
      if (!url.startsWith('http://') && !url.startsWith('https://')) continue;
      if (await repository.findDuplicateUrl(url) != null) {
        skipped++;
        continue;
      }
      await repository.create(url: url, title: link.text.trim().isEmpty ? url : link.text.trim());
      imported++;
    }
    return BookmarkTransferResult(imported: imported, skipped: skipped);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
