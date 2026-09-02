import 'package:flutter/material.dart';

import '../../../../data/database_view_creation_service.dart';
import '../../../../data/database_view_management_service.dart';
import '../../../../data/database_view_open_mode_service.dart';
import '../../../../data/database_view_store.dart';
import '../../../../database/database_definition.dart';
import '../../../../domain/object_type_defaults.dart';

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

  DatabaseViewCreationService get _creation =>
      DatabaseViewCreationService(widget.store);
  DatabaseViewManagementService get _management =>
      DatabaseViewManagementService(widget.store);
  DatabaseViewOpenModeService get _openModes =>
      DatabaseViewOpenModeService(widget.store);

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
      await widget.store.importLegacyBookmarkViews(
        workspaceId: widget.workspaceId,
      );
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

  DatabaseViewConfig? get _activeView {
    for (final view in _views) {
      if (view.id == widget.activeViewId) return view;
    }
    return _views.isEmpty ? null : _views.first;
  }

  Future<void> _createView() async {
    final source = _activeView;
    if (source == null) return;
    final duplicate = await _creation.duplicateCurrent(source);
    await _reload();
    if (!mounted) return;
    widget.onSelected(duplicate);
    widget.onViewsChanged?.call();
  }

  Future<void> _createBlankView() async {
    final blank = await _creation.createBlank(
      workspaceId: widget.workspaceId,
      definition: widget.definition,
    );
    await _reload();
    if (!mounted) return;
    widget.onSelected(blank);
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
          onFieldSubmitted: (_) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result?.trim().isEmpty != false) return;
    await _management.rename(view, result!);
    await _reload();
    widget.onViewsChanged?.call();
  }

  Future<void> _editOpenMode(DatabaseViewConfig view) async {
    ObjectOpenMode? current;
    try {
      current = _openModes.overrideFor(view);
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Objectの開き方を読み込めませんでした: $error')),
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Objectの開き方'),
        children: [
          ListTile(
            leading: Icon(
              current == null
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: const Text('継承（デフォルト）'),
            subtitle: const Text('Database / ObjectType の設定を使用'),
            onTap: () => Navigator.pop(dialogContext, 'inherit'),
          ),
          ListTile(
            leading: Icon(
              current == ObjectOpenMode.sidePeek
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: const Text('サイドピーク'),
            onTap: () =>
                Navigator.pop(dialogContext, ObjectOpenMode.sidePeek.name),
          ),
          ListTile(
            leading: Icon(
              current == ObjectOpenMode.centerPeek
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: const Text('センターピーク'),
            onTap: () =>
                Navigator.pop(dialogContext, ObjectOpenMode.centerPeek.name),
          ),
          ListTile(
            leading: Icon(
              current == ObjectOpenMode.fullPage
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: const Text('フルページ'),
            onTap: () =>
                Navigator.pop(dialogContext, ObjectOpenMode.fullPage.name),
          ),
        ],
      ),
    );
    if (selected == null) return;
    final mode = selected == 'inherit'
        ? null
        : ObjectOpenMode.values.singleWhere((item) => item.name == selected);
    final updated = await _openModes.setOverride(view: view, mode: mode);
    await _reload();
    if (!mounted) return;
    if (updated.id == widget.activeViewId) widget.onSelected(updated);
    widget.onViewsChanged?.call();
  }

  Future<void> _duplicate(DatabaseViewConfig view) async {
    final duplicate = await _creation.duplicateCurrent(view);
    await _reload();
    if (!mounted) return;
    widget.onSelected(duplicate);
    widget.onViewsChanged?.call();
  }

  Future<void> _delete(DatabaseViewConfig view) async {
    if (_views.length <= 1) return;
    await _management.delete(view);
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
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: _views.length,
        footer: Padding(
          padding: const EdgeInsets.only(left: 2, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('database-view-add-button'),
                tooltip: '現在のビューを複製',
                visualDensity: VisualDensity.compact,
                onPressed: _activeView == null ? null : _createView,
                icon: const Icon(Icons.add, size: 18),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('database-view-create-menu'),
                tooltip: 'ビュー作成メニュー',
                iconSize: 16,
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'blank') _createBlankView();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'blank',
                    child: Text('空のViewを作成'),
                  ),
                ],
              ),
            ],
          ),
        ),
        onReorderItem: (oldIndex, newIndex) async {
          final next = [..._views];
          final moved = next.removeAt(oldIndex);
          next.insert(newIndex, moved);
          setState(() => _views = next);
          try {
            await _management.reorder(
              workspaceId: widget.workspaceId,
              databaseKey: widget.definition.key,
              orderedViewIds: next.map((view) => view.id).toList(),
            );
            widget.onViewsChanged?.call();
          } catch (_) {
            await _reload();
            rethrow;
          }
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
                          color: selected
                              ? scheme.primary
                              : Colors.transparent,
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
                          color: selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          view.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        PopupMenuButton<String>(
                          key: ValueKey('database-view-menu-${view.id}'),
                          tooltip: 'ビュー設定',
                          iconSize: 15,
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'rename') _rename(view);
                            if (value == 'openMode') _editOpenMode(view);
                            if (value == 'duplicate') _duplicate(view);
                            if (value == 'delete') _delete(view);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('名前を変更'),
                            ),
                            const PopupMenuItem(
                              value: 'openMode',
                              child: Text('Objectの開き方'),
                            ),
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Text('複製'),
                            ),
                            if (_views.length > 1) ...const [
                              PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('削除'),
                              ),
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
    );
  }
}
