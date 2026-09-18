import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum UnifiedCommandPaletteItemKind { destination, database, object }

class UnifiedCommandPaletteItem {
  const UnifiedCommandPaletteItem({
    required this.keyName,
    required this.kind,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconText,
    this.navigationIndex,
    this.databaseId,
    this.objectId,
    this.recoveryOnSearchFailure = false,
  });

  final String keyName;
  final UnifiedCommandPaletteItemKind kind;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final String? iconText;
  final int? navigationIndex;
  final int? databaseId;
  final int? objectId;
  final bool recoveryOnSearchFailure;
}

Future<UnifiedCommandPaletteItem?> showUnifiedCommandPalette({
  required BuildContext context,
  required List<UnifiedCommandPaletteItem> staticItems,
  required Future<List<UnifiedCommandPaletteItem>> Function(String query)
  searchObjects,
}) {
  return showDialog<UnifiedCommandPaletteItem>(
    context: context,
    builder: (dialogContext) => UnifiedCommandPalette(
      staticItems: staticItems,
      searchObjects: searchObjects,
    ),
  );
}

class UnifiedCommandPalette extends StatefulWidget {
  const UnifiedCommandPalette({
    super.key,
    required this.staticItems,
    required this.searchObjects,
  });

  final List<UnifiedCommandPaletteItem> staticItems;
  final Future<List<UnifiedCommandPaletteItem>> Function(String query)
  searchObjects;

  @override
  State<UnifiedCommandPalette> createState() => _UnifiedCommandPaletteState();
}

class _UnifiedCommandPaletteState extends State<UnifiedCommandPalette> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  Timer? _debounce;
  int _searchGeneration = 0;
  List<UnifiedCommandPaletteItem> _objectItems =
      const <UnifiedCommandPaletteItem>[];
  String? _selectedKey;
  bool _searching = false;
  bool _searchFailed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  String get _normalizedQuery => _controller.text.trim().toLowerCase();

  List<UnifiedCommandPaletteItem> get _visibleStaticItems {
    final query = _normalizedQuery;
    if (query.isEmpty) return widget.staticItems;
    return widget.staticItems
        .where(
          (item) =>
              (_searchFailed && item.recoveryOnSearchFailure) ||
              item.label.toLowerCase().contains(query) ||
              (item.subtitle?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);
  }

  List<UnifiedCommandPaletteItem> get _visibleItems =>
      <UnifiedCommandPaletteItem>[..._visibleStaticItems, ..._objectItems];

  void _ensureSelection(List<UnifiedCommandPaletteItem> items) {
    if (items.isEmpty) {
      _selectedKey = null;
      return;
    }
    if (items.any((item) => item.keyName == _selectedKey)) return;
    _selectedKey = items.first.keyName;
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    final query = value.trim();
    setState(() {
      _objectItems = const <UnifiedCommandPaletteItem>[];
      _searchFailed = false;
      _searching = query.isNotEmpty;
      _ensureSelection(_visibleItems);
    });
    if (query.isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 160), () async {
      try {
        final results = await widget.searchObjects(query);
        if (!mounted ||
            generation != _searchGeneration ||
            _controller.text.trim() != query) {
          return;
        }
        setState(() {
          _objectItems = results;
          _searching = false;
          _ensureSelection(_visibleItems);
        });
      } catch (_) {
        if (!mounted ||
            generation != _searchGeneration ||
            _controller.text.trim() != query) {
          return;
        }
        setState(() {
          _objectItems = const <UnifiedCommandPaletteItem>[];
          _searching = false;
          _searchFailed = true;
          _ensureSelection(_visibleItems);
        });
      }
    });
  }

  void _moveSelection(int delta) {
    final items = _visibleItems;
    if (items.isEmpty) return;
    _ensureSelection(items);
    var index = items.indexWhere((item) => item.keyName == _selectedKey);
    if (index < 0) index = 0;
    index = (index + delta).clamp(0, items.length - 1).toInt();
    setState(() => _selectedKey = items[index].keyName);
  }

  void _activateSelected() {
    final items = _visibleItems;
    if (items.isEmpty) return;
    _ensureSelection(items);
    final selected = items.firstWhere(
      (item) => item.keyName == _selectedKey,
      orElse: () => items.first,
    );
    Navigator.of(context).pop(selected);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _activateSelected();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _leading(UnifiedCommandPaletteItem item) {
    if (item.iconText?.isNotEmpty == true) {
      return SizedBox(
        width: 24,
        child: Center(
          child: Text(item.iconText!, style: const TextStyle(fontSize: 18)),
        ),
      );
    }
    return Icon(item.icon ?? Icons.description_outlined, size: 20);
  }

  String _groupLabel(UnifiedCommandPaletteItemKind kind) => switch (kind) {
    UnifiedCommandPaletteItemKind.destination => '移動',
    UnifiedCommandPaletteItemKind.database => 'データベース',
    UnifiedCommandPaletteItemKind.object => 'オブジェクト',
  };

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    _ensureSelection(items);
    return AlertDialog(
      title: const Text('コマンドパレット'),
      content: SizedBox(
        width: 560,
        height: 440,
        child: Column(
          children: [
            Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                key: const ValueKey<String>('unified-command-palette-query'),
                controller: _controller,
                focusNode: _queryFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'オブジェクト、データベース、移動先を検索',
                ),
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _activateSelected(),
              ),
            ),
            const SizedBox(height: 8),
            if (_searching) const LinearProgressIndicator(minHeight: 2),
            if (_searchFailed)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('オブジェクト検索を利用できません。全文検索から再試行できます。'),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('一致する項目がありません'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final previousKind = index == 0
                            ? null
                            : items[index - 1].kind;
                        final selected = item.keyName == _selectedKey;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (previousKind != item.kind)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  4,
                                ),
                                child: Text(
                                  _groupLabel(item.kind),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ListTile(
                              key: ValueKey<String>(
                                'unified-command-palette-item-${item.keyName}',
                              ),
                              selected: selected,
                              leading: _leading(item),
                              title: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: item.subtitle == null
                                  ? null
                                  : Text(
                                      item.subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: selected
                                  ? const Icon(Icons.keyboard_return, size: 16)
                                  : null,
                              onTap: () => Navigator.of(context).pop(item),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
