import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../repositories/object_global_search_service.dart';
import '../repositories/object_search_result_resolver.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_empty_state.dart';
import 'object_inspector_page.dart';

/// Global search surface backed by the canonical Object search projection.
///
/// This page deliberately knows nothing about legacy Bookmark ids or detail
/// panels. Results resolve to canonical Objects/ObjectTypes and open through the
/// shared [ObjectInspectorPage].
class ObjectGlobalSearchPage extends StatefulWidget {
  const ObjectGlobalSearchPage({
    super.key,
    required this.store,
    required this.workspaceId,
    this.searchService,
  });

  final GenericDatabaseStore store;
  final int workspaceId;
  final ObjectGlobalSearchService? searchService;

  @override
  State<ObjectGlobalSearchPage> createState() => _ObjectGlobalSearchPageState();
}

class _ObjectGlobalSearchPageState extends State<ObjectGlobalSearchPage> {
  late ObjectGlobalSearchService _searchService;
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<ResolvedObjectSearchHit> _results = const <ResolvedObjectSearchHit>[];
  bool _indexing = true;
  bool _searching = false;
  bool _searchFailed = false;

  @override
  void initState() {
    super.initState();
    _searchService =
        widget.searchService ?? ObjectGlobalSearchService(widget.store);
    _prepareIndex();
  }

  @override
  void didUpdateWidget(covariant ObjectGlobalSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.searchService != widget.searchService) {
      _searchService =
          widget.searchService ?? ObjectGlobalSearchService(widget.store);
      _prepareIndex();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _recordSearchFailure(String message, StackTrace stackTrace) {
    assert(() {
      developer.log(
        message,
        name: 'bookmark_app.object_global_search',
        stackTrace: stackTrace,
      );
      return true;
    }());
    if (!mounted) return;
    setState(() {
      _indexing = false;
      _searching = false;
      _searchFailed = true;
    });
  }

  Future<void> _prepareIndex() async {
    if (mounted) {
      setState(() {
        _indexing = true;
        _searchFailed = false;
      });
    }
    try {
      await _searchService.rebuildWorkspace(widget.workspaceId);
      if (!mounted) return;
      setState(() => _indexing = false);
      if (_controller.text.trim().isNotEmpty) {
        await _search(_controller.text);
      }
    } catch (_, stackTrace) {
      _recordSearchFailure('Object global search index rebuild failed.', stackTrace);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (mounted) setState(() {});
    if (value.trim().isEmpty) {
      setState(() {
        _results = const <ResolvedObjectSearchHit>[];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 220),
      () => _search(value),
    );
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || _indexing) return;
    if (mounted) {
      setState(() {
        _searching = true;
        _searchFailed = false;
      });
    }
    try {
      final results = await _searchService.search(
        workspaceId: widget.workspaceId,
        rawQuery: query,
        limit: 120,
      );
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_, stackTrace) {
      _recordSearchFailure('Object global search query failed.', stackTrace);
    }
  }

  Future<void> _openResult(ResolvedObjectSearchHit result) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ObjectInspectorPage(
          store: widget.store,
          objectStore: ObjectStore(widget.store),
          objectId: result.object.id,
        ),
      ),
    );
  }

  Widget _resultList() {
    if (_indexing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchFailed) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: '全文検索を準備できませんでした',
        message: '検索インデックスを再構築して、もう一度お試しください。',
        actionLabel: '検索インデックスを再構築',
        onAction: _prepareIndex,
      );
    }
    if (_controller.text.trim().isEmpty) {
      return AppEmptyState(
        icon: Icons.manage_search,
        title: 'オブジェクトを横断検索',
        message: 'タイトル・エイリアス・プロパティ・本文などを、すべてのオブジェクトから検索します。',
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
        title: '一致するオブジェクトがありません',
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
        final result = _results[index];
        final icon = result.objectType.icon.trim();
        final snippet = result.hit.snippet.trim();
        return ListTile(
          key: ValueKey('object-global-search-result-${result.object.id}'),
          leading: SizedBox(
            width: UiTokens.iconLarge,
            child: Center(
              child: icon.isEmpty
                  ? const Icon(Icons.description_outlined)
                  : Text(icon, style: const TextStyle(fontSize: UiTokens.textLg)),
            ),
          ),
          title: Text(
            result.object.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.objectType.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: UiTokens.textSm,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (snippet.isNotEmpty)
                Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, size: UiTokens.iconNormal),
          onTap: () => _openResult(result),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                hintText: 'タイトル、エイリアス、プロパティ、本文などを検索',
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
          Expanded(child: _resultList()),
        ],
      ),
    );
  }
}
