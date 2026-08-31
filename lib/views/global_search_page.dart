import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../repositories/full_text_search_repository.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/bookmark_detail_panel.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  late final FullTextSearchRepository _searchRepository;
  final _controller = TextEditingController();
  Timer? _debounce;
  List<_ResolvedSearchHit> _results = const [];
  bool _indexing = true;
  bool _searching = false;
  int? _selectedBookmarkId;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _searchRepository = FullTextSearchRepository(widget.repository);
    _prepareIndex();
  }

  @override
  void didUpdateWidget(covariant GlobalSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _searchRepository = FullTextSearchRepository(widget.repository);
      _prepareIndex();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prepareIndex() async {
    if (mounted) {
      setState(() {
        _indexing = true;
        _error = null;
      });
    }
    try {
      await _searchRepository.rebuild();
      if (!mounted) return;
      setState(() => _indexing = false);
      if (_controller.text.trim().isNotEmpty) await _search(_controller.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _indexing = false;
        _error = error;
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () => _search(value));
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _selectedBookmarkId = null;
      });
    }
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || _indexing) return;
    if (mounted) setState(() => _searching = true);
    try {
      final hits = await _searchRepository.search(query, limit: 120);
      final bookmarks = await widget.repository.watchAll().first;
      final byId = {for (final bookmark in bookmarks) bookmark.id: bookmark};
      final resolved = <_ResolvedSearchHit>[];
      for (final hit in hits) {
        final bookmark = byId[hit.bookmarkId];
        if (bookmark != null) {
          resolved.add(_ResolvedSearchHit(bookmark: bookmark, hit: hit));
        }
      }
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = resolved;
        _searching = false;
        if (_selectedBookmarkId != null &&
            !resolved.any((item) => item.bookmark.id == _selectedBookmarkId)) {
          _selectedBookmarkId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = error;
      });
    }
  }

  String _secondaryText(BookmarkItem bookmark) {
    final parts = <String>[
      if (bookmark.tags.isNotEmpty) bookmark.tags.map((tag) => tag.name).join(', '),
      if (bookmark.people.isNotEmpty) bookmark.people.map((person) => person.name).join(', '),
      if (bookmark.collections.isNotEmpty)
        bookmark.collections.map((collection) => collection.name).join(', '),
    ];
    return parts.join(' · ');
  }

  Widget _resultList() {
    if (_indexing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: '全文検索を準備できませんでした',
        message: '$_error',
        actionLabel: '検索インデックスを再構築',
        onAction: _prepareIndex,
      );
    }
    if (_controller.text.trim().isEmpty) {
      return AppEmptyState(
        icon: Icons.manage_search,
        title: 'ブックマークを横断検索',
        message: 'タイトル・URL・説明・タグ・人物・コレクションをSQLite FTS5で検索します。',
        actionLabel: 'インデックスを更新',
        onAction: _prepareIndex,
      );
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off,
        title: '一致するブックマークがありません',
        message: '別のキーワードや、より短い語句で検索してみてください。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        UiTokens.space16,
        UiTokens.space8,
        UiTokens.space16,
        UiTokens.space24,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _results[index];
        final bookmark = item.bookmark;
        final secondary = _secondaryText(bookmark);
        return ListTile(
          selected: _selectedBookmarkId == bookmark.id,
          leading: const Icon(Icons.bookmark_outline, size: UiTokens.iconNormal),
          title: Text(
            bookmark.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.hit.snippet.trim().isNotEmpty)
                Text(
                  item.hit.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (secondary.isNotEmpty)
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: UiTokens.textSm,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, size: UiTokens.iconNormal),
          onTap: () => setState(() => _selectedBookmarkId = bookmark.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _results
        .where((item) => item.bookmark.id == _selectedBookmarkId)
        .map((item) => item.bookmark)
        .firstOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: UiTokens.appBarHeight,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: UiTokens.iconNormal),
            SizedBox(width: UiTokens.space6),
            Text('全文検索', style: TextStyle(fontSize: UiTokens.textLg)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '検索インデックスを更新',
            onPressed: _indexing ? null : _prepareIndex,
            icon: const Icon(Icons.refresh, size: UiTokens.iconNormal),
          ),
          const SizedBox(width: UiTokens.space8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(UiTokens.space12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'タイトル、タグ、人物、コレクションなどを検索',
                prefixIcon: const Icon(Icons.search, size: UiTokens.iconNormal),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: UiTokens.iconSmall),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _resultList()),
                if (selected != null) ...[
                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                  SizedBox(
                    width: 430,
                    child: BookmarkDetailPanel(
                      key: ValueKey(selected.id),
                      repository: widget.repository,
                      bookmark: selected,
                      onClose: () => setState(() => _selectedBookmarkId = null),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedSearchHit {
  const _ResolvedSearchHit({required this.bookmark, required this.hit});
  final BookmarkItem bookmark;
  final BookmarkSearchHit hit;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
