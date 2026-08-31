import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/tag_group_store.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  late final TagGroupStore _tagGroupStore;
  var _query = '';
  var _ready = false;
  var _includeDescendants = true;
  final Set<int> _selectedTagIds = {};

  @override
  void initState() {
    super.initState();
    _tagGroupStore = TagGroupStore(widget.repository.lifecycleStore.database);
    _initialize();
  }

  Future<void> _initialize() async {
    await _tagGroupStore.initialize();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _tagGroupStore.dispose();
    super.dispose();
  }

  bool _matches(String? value, String query) =>
      query.isEmpty || value?.toLowerCase().contains(query) == true;

  bool _bookmarkTextMatches(BookmarkItem item, String query) {
    if (query.isEmpty) return true;
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

  Set<int> _descendants(int tagId, List<Tag> tags) {
    final result = <int>{};
    void visit(int parentId) {
      for (final child in tags.where((tag) => tag.parentTagId == parentId)) {
        if (result.add(child.id)) visit(child.id);
      }
    }
    visit(tagId);
    return result;
  }

  bool _bookmarkFacetMatches(
    BookmarkItem bookmark,
    List<Tag> allTags,
    Map<int, int?> groupByTag,
  ) {
    if (_selectedTagIds.isEmpty) return true;

    final selectedByGroup = <int?, Set<int>>{};
    for (final id in _selectedTagIds) {
      selectedByGroup.putIfAbsent(groupByTag[id], () => <int>{}).add(id);
    }

    final bookmarkIds = bookmark.tags.map((tag) => tag.id).toSet();
    for (final selected in selectedByGroup.values) {
      final allowed = <int>{};
      for (final id in selected) {
        allowed.add(id);
        if (_includeDescendants) allowed.addAll(_descendants(id, allTags));
      }
      // OR inside a facet group, AND between facet groups.
      if (!allowed.any(bookmarkIds.contains)) return false;
    }
    return true;
  }

  Future<void> _openBookmark(BookmarkItem bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null) return;
    await widget.repository.recordOpen(bookmark);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<Tag> _childrenOf(int? parentId, List<Tag> tags, Set<int> allowedIds) => tags
      .where((tag) => tag.parentTagId == parentId && allowedIds.contains(tag.id))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Widget _facetTree(List<Tag> allTags, Set<int> ids, int? parentId, int depth) {
    final children = _childrenOf(parentId, allTags, ids);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.map((tag) {
        final nested = _childrenOf(tag.id, allTags, ids);
        final selected = _selectedTagIds.contains(tag.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.only(left: depth * 16, right: 2),
              controlAffinity: ListTileControlAffinity.leading,
              secondary: Icon(
                nested.isEmpty ? Icons.sell_outlined : Icons.folder_outlined,
                size: 16,
              ),
              value: selected,
              title: Text(tag.name, style: const TextStyle(fontSize: 12.5)),
              onChanged: (value) => setState(() {
                value == true
                    ? _selectedTagIds.add(tag.id)
                    : _selectedTagIds.remove(tag.id);
              }),
            ),
            if (nested.isNotEmpty) _facetTree(allTags, ids, tag.id, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _facetPanel(
    List<Tag> tags,
    List<TagGroupInfo> groups,
    Map<int, int?> groupByTag,
  ) {
    final groupedIds = <int, Set<int>>{};
    final ungrouped = <int>{};
    for (final tag in tags) {
      final groupId = groupByTag[tag.id];
      if (groupId == null) {
        ungrouped.add(tag.id);
      } else {
        groupedIds.putIfAbsent(groupId, () => <int>{}).add(tag.id);
      }
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SizedBox(
        width: 260,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('ファセット', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (_selectedTagIds.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_selectedTagIds.clear),
                    child: const Text('解除'),
                  ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('子タグも含める', style: TextStyle(fontSize: 12.5)),
              value: _includeDescendants,
              onChanged: (value) => setState(() => _includeDescendants = value),
            ),
            const Divider(),
            ...groups.where((group) => groupedIds[group.id]?.isNotEmpty == true).map(
              (group) => ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  group.name,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                children: [
                  _facetTree(tags, groupedIds[group.id]!, null, 0),
                ],
              ),
            ),
            if (ungrouped.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'その他タグ',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                children: [_facetTree(tags, ungrouped, null, 0)],
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 7),
        child: Text(
          '$label  $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final query = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('全文検索 / ファセット検索')),
      body: StreamBuilder<List<Tag>>(
        stream: widget.repository.watchTags(),
        builder: (context, tagSnapshot) => StreamBuilder<List<TagGroupInfo>>(
          stream: _tagGroupStore.watchGroups(),
          builder: (context, groupSnapshot) => StreamBuilder<Map<int, int?>>(
            stream: _tagGroupStore.watchTagGroupIds(),
            builder: (context, mapSnapshot) {
              final tags = tagSnapshot.data ?? const <Tag>[];
              final groups = groupSnapshot.data ?? const <TagGroupInfo>[];
              final groupByTag = mapSnapshot.data ?? const <int, int?>{};

              return Row(
                children: [
                  _facetPanel(tags, groups, groupByTag),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
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
                              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<BookmarkItem>>(
                            stream: widget.repository.watchAll(),
                            builder: (context, bookmarkSnapshot) =>
                                StreamBuilder<List<PhotoRecord>>(
                              stream: widget.repository.watchPhotos(),
                              builder: (context, photoSnapshot) =>
                                  StreamBuilder<List<Person>>(
                                stream: widget.repository.watchPeople(),
                                builder: (context, peopleSnapshot) =>
                                    StreamBuilder<List<CollectionRecord>>(
                                  stream: widget.repository.watchCollections(),
                                  builder: (context, collectionSnapshot) {
                                    final bookmarks = (bookmarkSnapshot.data ?? const <BookmarkItem>[])
                                        .where((item) =>
                                            _bookmarkTextMatches(item, query) &&
                                            _bookmarkFacetMatches(item, tags, groupByTag))
                                        .toList();

                                    final searchingText = query.isNotEmpty;
                                    final photos = searchingText
                                        ? (photoSnapshot.data ?? const <PhotoRecord>[])
                                            .where((photo) =>
                                                _matches(photo.title, query) ||
                                                _matches(photo.note, query) ||
                                                _matches(photo.tags, query))
                                            .toList()
                                        : const <PhotoRecord>[];
                                    final people = searchingText
                                        ? (peopleSnapshot.data ?? const <Person>[])
                                            .where((person) =>
                                                _matches(person.name, query) ||
                                                _matches(person.note, query))
                                            .toList()
                                        : const <Person>[];
                                    final matchingTags = searchingText
                                        ? tags.where((tag) => _matches(tag.name, query)).toList()
                                        : const <Tag>[];
                                    final collections = searchingText
                                        ? (collectionSnapshot.data ?? const <CollectionRecord>[])
                                            .where((collection) =>
                                                _matches(collection.name, query) ||
                                                _matches(collection.note, query))
                                            .toList()
                                        : const <CollectionRecord>[];

                                    if (bookmarks.isEmpty &&
                                        photos.isEmpty &&
                                        people.isEmpty &&
                                        matchingTags.isEmpty &&
                                        collections.isEmpty) {
                                      return Center(
                                        child: Text(
                                          query.isEmpty && _selectedTagIds.isEmpty
                                              ? '検索語を入力するか、左のファセットを選択してください'
                                              : '一致するデータがありません',
                                        ),
                                      );
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
                                                subtitle: collection.note == null ? null : Text(collection.note!),
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
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
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
                                        if (matchingTags.isNotEmpty) ...[
                                          _sectionTitle('タグ', matchingTags.length),
                                          Wrap(
                                            spacing: 7,
                                            runSpacing: 7,
                                            children: matchingTags.map((tag) => Chip(label: Text(tag.name))).toList(),
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
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
