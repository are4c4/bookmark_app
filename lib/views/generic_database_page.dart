import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../data/database_view_store.dart';
import '../data/generic_database_store.dart';
import '../database/database_definition.dart';
import '../features/database/presentation/database_property_presenter.dart';
import '../widgets/database_create_tiles.dart';
import '../widgets/database_view_tabs.dart';
import '../widgets/notion_inline_field.dart';
import '../widgets/resizable_detail_pane.dart';

class GenericDatabasePage extends StatefulWidget {
  const GenericDatabasePage({
    super.key,
    required this.repository,
    required this.databaseId,
    required this.onDatabaseChanged,
  });

  final BookmarkRepository repository;
  final int databaseId;
  final VoidCallback onDatabaseChanged;

  @override
  State<GenericDatabasePage> createState() => _GenericDatabasePageState();
}

class _GenericDatabasePageState extends State<GenericDatabasePage> {
  late final GenericDatabaseStore _store;
  late final DatabaseViewStore _viewStore;
  GenericDatabaseDefinitionRecord? _database;
  List<GenericPropertyRecord> _properties = const [];
  List<GenericRecord> _records = const [];
  DatabaseViewConfig? _activeView;
  int? _selectedRecordId;
  String _query = '';
  bool _loading = true;

  static const _propertyTypes = <String, String>{
    'text': 'テキスト',
    'number': '数値',
    'select': 'セレクト',
    'multiSelect': 'マルチセレクト',
    'checkbox': 'チェックボックス',
    'date': '日付',
    'url': 'URL',
    'rating': '評価',
  };

  @override
  void initState() {
    super.initState();
    _store = GenericDatabaseStore(widget.repository.workspaceStore.database);
    _viewStore = DatabaseViewStore(widget.repository.workspaceStore.database);
    _reload();
  }

  @override
  void didUpdateWidget(covariant GenericDatabasePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.databaseId != widget.databaseId) {
      _activeView = null;
      _selectedRecordId = null;
      _query = '';
      _reload();
    }
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    final database = await _store.getDatabase(widget.databaseId);
    final properties = await _store.listProperties(widget.databaseId);
    final records = await _store.listRecords(widget.databaseId);
    if (!mounted) return;
    setState(() {
      _database = database;
      _properties = properties;
      _records = records;
      _loading = false;
    });
  }

  DatabaseDefinition get _definition => DatabaseDefinition(
        key: _database?.databaseKey ?? 'custom:${widget.databaseId}',
        label: _database?.name ?? 'データベース',
        icon: Icons.table_chart_outlined,
        properties: _properties
            .map(
              (property) => DatabasePropertyDefinition(
                key: 'p:${property.id}',
                label: property.name,
                type: _databasePropertyType(property.type),
                icon: _propertyIcon(property.type),
              ),
            )
            .toList(),
        defaultLayout: 'table',
        supportedLayouts: const ['gallery', 'list', 'table'],
      );

  DatabasePropertyType _databasePropertyType(String type) => switch (type) {
        'number' => DatabasePropertyType.number,
        'select' => DatabasePropertyType.select,
        'multiSelect' => DatabasePropertyType.multiSelect,
        'checkbox' => DatabasePropertyType.checkbox,
        'date' => DatabasePropertyType.date,
        'url' => DatabasePropertyType.url,
        'rating' => DatabasePropertyType.rating,
        _ => DatabasePropertyType.text,
      };

  IconData _propertyIcon(String type) => switch (type) {
        'number' => Icons.numbers,
        'select' => Icons.arrow_drop_down_circle_outlined,
        'multiSelect' => Icons.sell_outlined,
        'checkbox' => Icons.check_box_outlined,
        'date' => Icons.calendar_today_outlined,
        'url' => Icons.link,
        'rating' => Icons.star_outline,
        _ => Icons.text_fields,
      };

  List<GenericPropertyRecord> get _orderedVisibleProperties {
    final order = _activeView?.propertyOrder ?? const <String>[];
    final visible = (_activeView?.visibleProperties ?? const <String>[]).toSet();
    final byKey = {for (final property in _properties) 'p:${property.id}': property};
    final result = <GenericPropertyRecord>[];
    for (final key in order) {
      final property = byKey[key];
      if (property != null && (visible.isEmpty || visible.contains(key))) {
        result.add(property);
      }
    }
    for (final property in _properties) {
      if (!result.any((item) => item.id == property.id) &&
          (visible.isEmpty || visible.contains('p:${property.id}'))) {
        result.add(property);
      }
    }
    return result;
  }

  Future<void> _selectView(DatabaseViewConfig view) async {
    final query = (view.filters['query'] as String?) ?? '';
    setState(() {
      _activeView = view;
      _query = query;
    });
  }

  Future<void> _saveView({
    String? layoutType,
    String? query,
    List<String>? propertyOrder,
    List<String>? visibleProperties,
  }) async {
    final active = _activeView;
    if (active == null) return;
    final next = active.copyWith(
      layoutType: layoutType ?? active.layoutType,
      filters: {...active.filters, if (query != null) 'query': query},
      propertyOrder: propertyOrder ?? active.propertyOrder,
      visibleProperties: visibleProperties ?? active.visibleProperties,
    );
    await _viewStore.updateView(next);
    if (mounted) setState(() => _activeView = next);
  }

  Future<void> _createRecord(String title) async {
    final id = await _store.createRecord(databaseId: widget.databaseId, title: title);
    await _reload();
    if (mounted) setState(() => _selectedRecordId = id);
  }

  Future<void> _createProperty() async {
    var name = '';
    var type = 'text';
    var optionsText = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('プロパティを追加'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '名前'),
                  onChanged: (value) => name = value,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '種類'),
                  items: _propertyTypes.entries
                      .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: (value) => setLocalState(() => type = value ?? 'text'),
                ),
                if (type == 'select' || type == 'multiSelect') ...[
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '選択肢',
                      hintText: '例: 未読, 読書中, 読了',
                    ),
                    onChanged: (value) => optionsText = value,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('追加')),
          ],
        ),
      ),
    );
    if (ok != true || name.trim().isEmpty) return;
    final options = optionsText
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    await _store.createProperty(
      databaseId: widget.databaseId,
      name: name,
      type: type,
      config: options.isEmpty ? const {} : {'options': options},
    );
    await _reload();
    final active = _activeView;
    if (active != null) {
      final key = 'p:${_properties.last.id}';
      await _saveView(
        propertyOrder: [...active.propertyOrder, key],
        visibleProperties: [...active.visibleProperties, key],
      );
    }
  }

  Future<void> _reorderProperties(List<GenericPropertyRecord> next) async {
    final keys = next.map((property) => 'p:${property.id}').toList();
    await _saveView(propertyOrder: keys);
  }

  GenericRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedRecordId) return record;
    }
    return null;
  }

  List<GenericRecord> get _filteredRecords {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return _records;
    return _records.where((record) {
      if (record.title.toLowerCase().contains(normalized)) return true;
      return record.values.values.any((value) => '$value'.toLowerCase().contains(normalized));
    }).toList();
  }

  String _displayValue(GenericPropertyRecord property, dynamic value) =>
      formatDatabasePropertyValue(_databasePropertyType(property.type), value);

  Widget _gallery(List<GenericRecord> records) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 180,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: records.length + 1,
        itemBuilder: (context, index) {
          if (index == records.length) {
            return DatabaseCreateCard(label: '新規ページ', onCreate: _createRecord);
          }
          final record = records[index];
          final scheme = Theme.of(context).colorScheme;
          return Material(
            color: record.id == _selectedRecordId
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _selectedRecordId = record.id),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ..._orderedVisibleProperties.take(4).map(
                          (property) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '${property.name}: ${_displayValue(property, record.values[property.id])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _list(List<GenericRecord> records) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 80),
        itemCount: records.length + 1,
        itemBuilder: (context, index) {
          if (index == records.length) {
            return DatabaseCreateRow(
              label: '新規ページ',
              icon: Icons.add,
              hintText: '名前を入力して Enter',
              onCreate: _createRecord,
            );
          }
          final record = records[index];
          return ListTile(
            selected: record.id == _selectedRecordId,
            leading: const Icon(Icons.description_outlined, size: 18),
            title: Text(record.title),
            subtitle: _orderedVisibleProperties.isEmpty
                ? null
                : Text(
                    _orderedVisibleProperties
                        .map((property) => _displayValue(property, record.values[property.id]))
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () => setState(() => _selectedRecordId = record.id),
          );
        },
      );

  Widget _table(List<GenericRecord> records) {
    final properties = _orderedVisibleProperties;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DataTable(
            columns: [
              const DataColumn(label: Text('名前')),
              ...properties.map((property) => DataColumn(label: Text(property.name))),
            ],
            rows: records
                .map(
                  (record) => DataRow(
                    selected: record.id == _selectedRecordId,
                    onSelectChanged: (_) => setState(() => _selectedRecordId = record.id),
                    cells: [
                      DataCell(Text(record.title)),
                      ...properties.map(
                        (property) => DataCell(
                          Text(_displayValue(property, record.values[property.id])),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          SizedBox(
            width: 320,
            child: DatabaseCreateRow(
              label: '新規ページ',
              icon: Icons.add,
              hintText: '名前を入力して Enter',
              onCreate: _createRecord,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editValue(GenericRecord record, GenericPropertyRecord property) async {
    final current = record.values[property.id];
    if (property.type == 'checkbox') {
      await _store.setValue(recordId: record.id, propertyId: property.id, value: current != true);
      await _reload();
      return;
    }
    if (property.type == 'rating') {
      final next = ((current is num ? current.toInt() : 0) + 1) % 6;
      await _store.setValue(recordId: record.id, propertyId: property.id, value: next);
      await _reload();
      return;
    }
    if (property.type == 'select') {
      final options = (property.config['options'] as List?)?.whereType<String>().toList() ?? const [];
      final selected = await showMenu<String>(
        context: context,
        position: const RelativeRect.fromLTRB(300, 220, 300, 0),
        items: options.map((value) => PopupMenuItem(value: value, child: Text(value))).toList(),
      );
      if (selected != null) {
        await _store.setValue(recordId: record.id, propertyId: property.id, value: selected);
        await _reload();
      }
      return;
    }
    var value = current == null ? '' : '$current';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(property.name),
        content: TextFormField(
          initialValue: value,
          autofocus: true,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, value), child: const Text('保存')),
        ],
      ),
    );
    if (result == null) return;
    dynamic parsed = result;
    if (property.type == 'number') parsed = num.tryParse(result);
    if (property.type == 'multiSelect') {
      parsed = result.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    }
    await _store.setValue(recordId: record.id, propertyId: property.id, value: parsed);
    await _reload();
  }

  Widget _detail(GenericRecord record) {
    final scheme = Theme.of(context).colorScheme;
    final properties = _orderedVisibleProperties;
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Text('詳細', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: '削除',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    await _store.deleteRecord(record.id);
                    if (mounted) setState(() => _selectedRecordId = null);
                    await _reload();
                  },
                ),
                IconButton(
                  tooltip: '閉じる',
                  icon: const Icon(Icons.close, size: 19),
                  onPressed: () => setState(() => _selectedRecordId = null),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
              children: [
                NotionInlineField(
                  value: record.title,
                  hintText: '名前',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  onSaved: (value) async {
                    await _store.renameRecord(record.id, value);
                    await _reload();
                  },
                ),
                const SizedBox(height: 18),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: properties.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    final next = [...properties];
                    final moved = next.removeAt(oldIndex);
                    next.insert(newIndex, moved);
                    await _reorderProperties(next);
                    if (mounted) setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final property = properties[index];
                    final value = record.values[property.id];
                    return ReorderableDragStartListener(
                      key: ValueKey(property.id),
                      index: index,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: () => _editValue(record, property),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Icon(Icons.drag_indicator, size: 15, color: scheme.onSurfaceVariant.withValues(alpha: .55)),
                              const SizedBox(width: 6),
                              Icon(_propertyIcon(property.type), size: 17, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 9),
                              SizedBox(
                                width: 120,
                                child: Text(property.name, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                              ),
                              Expanded(
                                child: Text(
                                  _displayValue(property, value).isEmpty ? 'なし' : _displayValue(property, value),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _displayValue(property, value).isEmpty
                                        ? scheme.onSurfaceVariant.withValues(alpha: .55)
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _createProperty,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('プロパティを追加'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final database = _database;
    if (database == null) return const Center(child: Text('データベースが見つかりません'));
    final records = _filteredRecords;
    final selected = _selectedRecord;
    final layout = _activeView?.layoutType ?? 'table';

    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Text(database.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NotionInlineField(
                      value: database.name,
                      hintText: 'データベース名',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      onSaved: (value) async {
                        await _store.renameDatabase(database.id, value);
                        widget.onDatabaseChanged();
                        await _reload();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'プロパティを追加',
                    onPressed: _createProperty,
                    icon: const Icon(Icons.add_circle_outline, size: 19),
                  ),
                ],
              ),
            ),
          ),
          DatabaseViewTabs(
            store: _viewStore,
            definition: _definition,
            workspaceId: widget.repository.workspaceId,
            activeViewId: _activeView?.id,
            onSelected: _selectView,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 7),
            child: Row(
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'gallery', icon: Icon(Icons.grid_view, size: 16)),
                    ButtonSegment(value: 'list', icon: Icon(Icons.view_list, size: 16)),
                    ButtonSegment(value: 'table', icon: Icon(Icons.table_rows, size: 16)),
                  ],
                  selected: {layout},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) _saveView(layoutType: selection.first);
                  },
                ),
                const Spacer(),
                SizedBox(
                  width: 250,
                  height: 36,
                  child: TextFormField(
                    key: ValueKey('${_activeView?.id}:$_query'),
                    initialValue: _query,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 17), hintText: '検索'),
                    onChanged: (value) {
                      setState(() => _query = value);
                      _saveView(query: value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: switch (layout) {
                    'gallery' => _gallery(records),
                    'list' => _list(records),
                    _ => _table(records),
                  },
                ),
                if (selected != null)
                  ResizableDetailPane(
                    storageKey: 'generic-db-${database.id}-detail',
                    initialWidth: 430,
                    child: _detail(selected),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
