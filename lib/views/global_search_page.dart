import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  var _query = '';

  bool _matches(String? value, String query) =>
      value?.toLowerCase().contains(query) == true;

  bool _bookmarkMatches(BookmarkItem item, String query) {
    if (_matches(item.title, query) ||
        _matches(item.url, query) ||
        _matches(item.description, query)) {
      return true;
    }
    if (item.tags.any((tag) => _matches(tag.name, query))) return true;
    if (item.people.any((person) =>
        _matches(person.name, query) || _matches(person.note, query))) {
      return true;
    }
    if (item.photos.any((photo) =>
        _matches(photo.title, query) ||
        _matches(photo.note, query) ||
        _matches(photo.tags, query))) {
      return true;
    }
    if (item.collections.any((collection) =>
        _matches(collection.name, query) || _matches(collection.note, query))) {
      return true;
    }
    return false;
  }

  Future<void> _openBookmark(BookmarkItem bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null) return;
    await widget.repository.recordOpen(bookmark);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _sectionTitle(String label, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 7),
        child: Text(
          '$label  $count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('全文検索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'タイトル、URL、説明、タグ、人物、写真、コレクションを検索…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF7F7F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? const Center(
                    child: Text(
                      'Profile内のデータを横断して検索できます',
                      style: TextStyle(color: Color(0xFF9B9A97)),
                    ),
                  )
                : StreamBuilder<List<BookmarkItem>>(
                    stream: widget.repository.watchAll(),
                    builder: (context, bookmarkSnapshot) =>
                        StreamBuilder<List<PhotoRecord>>(
                      stream: widget.repository.watchPhotos(),
                      builder: (context, photoSnapshot) =>
                          StreamBuilder<List<Person>>(
                        stream: widget.repository.watchPeople(),
                        builder: (context, peopleSnapshot) =>
                            StreamBuilder<List<Tag>>(
                          stream: widget.repository.watchTags(),
                          builder: (context, tagSnapshot) =>
                              StreamBuilder<List<CollectionRecord>>(
                            stream: widget.repository.watchCollections(),
                            builder: (context, collectionSnapshot) {
                              final bookmarks = (bookmarkSnapshot.data ?? const <BookmarkItem>[])
                                  .where((item) => _bookmarkMatches(item, query))
                                  .toList();
                              final photos = (photoSnapshot.data ?? const <PhotoRecord>[])
                                  .where((photo) =>
                                      _matches(photo.title, query) ||
                                      _matches(photo.note, query) ||
                                      _matches(photo.tags, query))
                                  .toList();
                              final people = (peopleSnapshot.data ?? const <Person>[])
                                  .where((person) =>
                                      _matches(person.name, query) ||
                                      _matches(person.note, query))
                                  .toList();
                              final tags = (tagSnapshot.data ?? const <Tag>[])
                                  .where((tag) => _matches(tag.name, query))
                                  .toList();
                              final collections =
                                  (collectionSnapshot.data ?? const <CollectionRecord>[])
                                      .where((collection) =>
                                          _matches(collection.name, query) ||
                                          _matches(collection.note, query))
                                      .toList();

                              final total = bookmarks.length +
                                  photos.length +
                                  people.length +
                                  tags.length +
                                  collections.length;
                              if (total == 0) {
                                return const Center(child: Text('一致するデータがありません'));
                              }

                              return ListView(
                                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                                children: [
                                  if (bookmarks.isNotEmpty) ...[
                                    _sectionTitle('ブックマーク', bookmarks.length),
                                    ...bookmarks.map((bookmark) => ListTile(
                                          dense: true,
                                          leading: bookmark.coverPhoto == null
                                              ? const Icon(Icons.bookmark_outline)
                                              : ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.file(
                                                    File(bookmark.coverPhoto!.path),
                                                    width: 42,
                                                    height: 32,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                        const Icon(Icons.bookmark_outline),
                                                  ),
                                                ),
                                          title: Text(bookmark.title),
                                          subtitle: Text(
                                            [
                                              bookmark.url,
                                              if (bookmark.tags.isNotEmpty)
                                                bookmark.tags.map((e) => e.name).join(', '),
                                              if (bookmark.collections.isNotEmpty)
                                                bookmark.collections.map((e) => e.name).join(', '),
                                            ].join('  ·  '),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onTap: () => _openBookmark(bookmark),
                                        )),
                                  ],
                                  if (collections.isNotEmpty) ...[
                                    _sectionTitle('コレクション / シリーズ', collections.length),
                                    ...collections.map((collection) => ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.collections_bookmark_outlined),
                                          title: Text(collection.name),
                                          subtitle: collection.note == null
                                              ? null
                                              : Text(collection.note!),
                                        )),
                                  ],
                                  if (people.isNotEmpty) ...[
                                    _sectionTitle('人物', people.length),
                                    ...people.map((person) => ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.person_outline),
                                          title: Text(person.name),
                                          subtitle: person.note == null ? null : Text(person.note!),
                                        )),
                                  ],
                                  if (photos.isNotEmpty) ...[
                                    _sectionTitle('写真', photos.length),
                                    ...photos.map((photo) => ListTile(
                                          dense: true,
                                          leading: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.file(
                                              File(photo.path),
                                              width: 42,
                                              height: 32,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.image_outlined),
                                            ),
                                          ),
                                          title: Text(photo.title ?? '写真 ${photo.id}'),
                                          subtitle: Text(
                                            [photo.note ?? '', photo.tags]
                                                .where((e) => e.trim().isNotEmpty)
                                                .join('  ·  '),
                                          ),
                                        )),
                                  ],
                                  if (tags.isNotEmpty) ...[
                                    _sectionTitle('タグ', tags.length),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 7,
                                      children: tags
                                          .map((tag) => Chip(label: Text(tag.name)))
                                          .toList(),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
