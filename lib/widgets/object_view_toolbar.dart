import 'package:flutter/material.dart';

import '../data/database_view_gallery_adapter.dart';
import '../data/database_view_group_adapter.dart';
import '../data/database_view_query_adapter.dart';
import '../data/database_view_store.dart';
import '../domain/object_model.dart';
import 'object_group_dialog.dart';
import 'object_query_dialog.dart';

class ObjectViewToolbar extends StatelessWidget {
  const ObjectViewToolbar({
    super.key,
    required this.view,
    required this.properties,
    required this.onViewChanged,
    this.supportedLayouts = const <String>['gallery', 'list', 'table', 'board'],
    this.showLayoutSelector = true,
  });

  final DatabaseViewConfig view;
  final List<ObjectPropertyDefinition> properties;
  final ValueChanged<DatabaseViewConfig> onViewChanged;
  final List<String> supportedLayouts;
  final bool showLayoutSelector;

  static const _queryAdapter = DatabaseViewQueryAdapter();
  static const _groupAdapter = DatabaseViewGroupAdapter();
  static const _galleryAdapter = DatabaseViewGalleryAdapter();

  @override
  Widget build(BuildContext context) {
    final query = _queryAdapter.decode(view);
    final group = _groupAdapter.decode(view);
    final galleryMode = _galleryAdapter.decode(view);
    final filterCount = query.filters.length;
    final sortCount = query.sorts.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ToolbarButton(
          icon: Icons.filter_alt_outlined,
          label: filterCount == 0 ? 'フィルター' : 'フィルター $filterCount',
          active: filterCount > 0,
          onPressed: () => _editQuery(context),
        ),
        _ToolbarButton(
          icon: Icons.swap_vert,
          label: sortCount == 0 ? '並び替え' : '並び替え $sortCount',
          active: sortCount > 0,
          onPressed: () => _editQuery(context),
        ),
        _ToolbarButton(
          icon: Icons.account_tree_outlined,
          label: group == null ? 'グループ' : _groupLabel(group.propertyId),
          active: group != null,
          onPressed: () => _editGroup(context),
        ),
        if (showLayoutSelector) _layoutMenu(context, group != null),
        if (view.layoutType == 'gallery') _galleryModeMenu(galleryMode),
      ],
    );
  }

  Future<void> _editQuery(BuildContext context) async {
    final state = _queryAdapter.decode(view);
    final result = await showObjectQueryDialog(
      context,
      properties: properties,
      initialFilters: state.filters,
      initialSorts: state.sorts,
    );
    if (result == null) return;
    onViewChanged(
      _queryAdapter.encode(
        view,
        filters: result.filters,
        sorts: result.sorts,
      ),
    );
  }

  Future<void> _editGroup(BuildContext context) async {
    final result = await showObjectGroupDialog(
      context,
      properties: properties,
      initialRule: _groupAdapter.decode(view),
    );
    if (result == null) return;
    onViewChanged(_groupAdapter.encode(view, group: result.rule));
  }

  Widget _layoutMenu(BuildContext context, bool hasGroup) {
    return PopupMenuButton<String>(
      tooltip: 'レイアウト',
      initialValue: view.layoutType,
      onSelected: (layout) {
        if (layout == 'board' && !hasGroup) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Boardを使うには先にグループ化を設定してください')),
          );
          return;
        }
        onViewChanged(view.copyWith(layoutType: layout));
      },
      itemBuilder: (_) => supportedLayouts
          .map(
            (layout) => PopupMenuItem<String>(
              value: layout,
              enabled: layout != 'board' || hasGroup,
              child: Row(
                children: [
                  Icon(_layoutIcon(layout), size: 17),
                  const SizedBox(width: 9),
                  Text(_layoutLabel(layout)),
                  if (layout == view.layoutType) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 16),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: _ToolbarButton(
        icon: _layoutIcon(view.layoutType),
        label: _layoutLabel(view.layoutType),
        active: true,
      ),
    );
  }

  Widget _galleryModeMenu(GalleryViewMode mode) {
    return PopupMenuButton<GalleryViewMode>(
      key: const ValueKey('gallery-mode-menu'),
      tooltip: 'ギャラリー表示',
      initialValue: mode,
      onSelected: (next) {
        onViewChanged(_galleryAdapter.encode(view, mode: next));
      },
      itemBuilder: (_) => GalleryViewMode.values
          .map(
            (candidate) => PopupMenuItem<GalleryViewMode>(
              value: candidate,
              child: Row(
                children: [
                  Icon(_galleryModeIcon(candidate), size: 17),
                  const SizedBox(width: 9),
                  Text(_galleryModeLabel(candidate)),
                  if (candidate == mode) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 16),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: _ToolbarButton(
        icon: _galleryModeIcon(mode),
        label: _galleryModeLabel(mode),
        active: mode == GalleryViewMode.masonry,
      ),
    );
  }

  String _groupLabel(int propertyId) {
    for (final property in properties) {
      if (property.id == propertyId) return property.name;
    }
    return 'グループ';
  }

  String _layoutLabel(String layout) => switch (layout) {
        'gallery' => 'ギャラリー',
        'list' => 'リスト',
        'board' => 'ボード',
        _ => 'テーブル',
      };

  IconData _layoutIcon(String layout) => switch (layout) {
        'gallery' => Icons.grid_view,
        'list' => Icons.view_list,
        'board' => Icons.view_kanban_outlined,
        _ => Icons.table_rows,
      };

  String _galleryModeLabel(GalleryViewMode mode) => switch (mode) {
        GalleryViewMode.fixed => '固定比率',
        GalleryViewMode.masonry => 'メイソンリー',
      };

  IconData _galleryModeIcon(GalleryViewMode mode) => switch (mode) {
        GalleryViewMode.fixed => Icons.grid_view,
        GalleryViewMode.masonry => Icons.view_quilt_outlined,
      };
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}
