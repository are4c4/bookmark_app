import 'package:flutter/material.dart';

import '../data/database_view_store.dart';
import '../database/database_definition.dart';
import 'database_create_tiles.dart';

class DatabaseViewTabs extends StatefulWidget {
  const DatabaseViewTabs({
    super.key,
    required this.store,
    required this.definition,
    required this.workspaceId,
    required this.activeViewId,
    required this.onSelected,
    this.onViewsChanged,
  });

  final DatabaseViewStore store;
  final DatabaseDefinition definition;
  final int workspaceId;
  final int? activeViewId;
  final ValueChanged<DatabaseViewConfig> onSelected;
  final VoidCallback? onViewsChanged;

  @override
  State<DatabaseViewTabs> createState() => _DatabaseViewTabsState();
}

class _DatabaseViewTabsState extends State<DatabaseViewTabs> {
  List<DatabaseViewConfig> _views = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload(initial: true);
  }

  @override
  void didUpdateWidget(covariant DatabaseViewTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.definition.key != widget.definition.key) {
      _reload(initial: true);
    }
  }

  Future<void> _reload({bool initial = false}) async {
    if (mounted && initial) setState(() => _loading = true);
    if (widget.definition.key == BuiltInDatabases.bookmarks.key) {
      await widget.store.importLegacyBookmarkViews(workspaceId: widget.workspaceId);
    }
    await widget.store.ensureDefaultView(
      workspaceId: widget.workspaceId,
      definition: widget.definition,
    );
    final views = await widget.store.listViews(
      workspaceId: widget.workspaceId,
      databaseKey: widget.definition.key,
    );
    if (!mounted) return;
    setState(() {
      _views = views;
      _loading = false;
    });
    if (views.isNotEmpty &&
        (widget.activeViewId == null ||
            !views.any((view) => view.id == widget.activeViewId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSelected(views.first);
      });
    }
  }

  Future<void> _createView() async {
    var layout = widget.definition.defaultLayout;
    final created = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ビューを追加'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatefulBuilder(
                builder: (context, setLocalState) => SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: widget.definition.supportedLayouts
                      .map(
                        (value) => ButtonSegment<String>(
                          value: value,
                          icon: Icon(
                            switch (value) {
                              'list' => Icons.view_list,
                              'table' => Icons.table_rows,
                              _ => Icons.grid_view,
                            },
                            size: 17,
                          ),
                          label: Text(
                            switch (value) {
                              'list' => 'リスト',
                              'table' => 'テーブル',
                              _ => 'ギャラリー',
                            },
                          ),
                        ),
                      )
                      .toList(),
                  selected: {layout},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      setLocalState(() => layout = selection.first);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              SafeQuickCreateField(
                autofocus: true,
                hintText: 'ビュー名を入力して Enter',
                prefixIcon: Icons.add,
                onSubmitted: (name) async {
                  final id = await widget.store.createView(
                    workspaceId: widget.workspaceId,
                    definition: widget.definition,
                    name: name,
                    layoutType: layout,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, '$id');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
    if (created == null) return;
    await _reload();
    final id = int.tryParse(created);
    final view = _views.where((candidate) => candidate.id == id).firstOrNull;
    if (view != null) widget.onSelected(view);
    widget.onViewsChanged?.call();
  }

  Future<void> _rename(DatabaseViewConfig view) async {
    var value = view.name;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ビュー名を変更'),
        content: TextFormField(
          initialValue: view.name,
          autofocus: true,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, value.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (result?.trim().isEmpty != false) return;
    await widget.store.renameView(view.id, result!);
    await _reload();
    widget.onViewsChanged?.call();
  }

  Future<void> _duplicate(DatabaseViewConfig view) async {
    final id = await widget.store.duplicateView(view);
    await _reload();
    final duplicate = _views.where((candidate) => candidate.id == id).firstOrNull;
    if (duplicate != null) widget.onSelected(duplicate);
    widget.onViewsChanged?.call();
  }

  Future<void> _delete(DatabaseViewConfig view) async {
    if (_views.length <= 1) return;
    await widget.store.deleteView(view.id);
    await _reload();
    widget.onViewsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5)),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: _views.length,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                final next = [..._views];
                final moved = next.removeAt(oldIndex);
                next.insert(newIndex, moved);
                setState(() => _views = next);
                await widget.store.reorderViews(next);
                widget.onViewsChanged?.call();
              },
              itemBuilder: (context, index) {
                final view = _views[index];
                final selected = view.id == widget.activeViewId;
                return ReorderableDragStartListener(
                  key: ValueKey(view.id),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: () => widget.onSelected(view),
                        child: Container(
                          padding: const EdgeInsets.only(left: 10, right: 2),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selected ? scheme.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                switch (view.layoutType) {
                                  'list' => Icons.view_list,
                                  'table' => Icons.table_rows,
                                  _ => Icons.grid_view,
                                },
                                size: 15,
                                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                view.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'ビュー設定',
                                iconSize: 15,
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'rename') _rename(view);
                                  if (value == 'duplicate') _duplicate(view);
                                  if (value == 'delete') _delete(view);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'rename', child: Text('名前を変更')),
                                  const PopupMenuItem(value: 'duplicate', child: Text('複製')),
                                  if (_views.length > 1) ...const [
                                    PopupMenuDivider(),
                                    PopupMenuItem(value: 'delete', child: Text('削除')),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'ビューを追加',
            visualDensity: VisualDensity.compact,
            onPressed: _createView,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
