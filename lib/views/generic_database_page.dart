import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../data/database_view_store.dart';
import '../data/generic_database_page_services.dart';
import '../data/generic_database_store.dart';
import '../data/generic_object_view_coordinator.dart';
import '../data/object_board_move_service.dart';
import '../data/object_computed_value_store.dart';
import '../data/object_graph_query_store.dart';
import '../data/object_store.dart';
import '../data/object_type_management_store.dart';
import '../database/database_definition.dart';
import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import '../features/database/presentation/database_property_presenter.dart';
import '../features/object/presentation/object_open_presentation_host.dart';
import '../widgets/database_collection_settings_dialog.dart';
import '../widgets/database_create_tiles.dart';
import '../widgets/database_view_tabs.dart';
import '../widgets/notion_inline_field.dart';
import '../widgets/object_board_view.dart';
import '../widgets/object_view_toolbar.dart';
import '../widgets/resizable_detail_pane.dart';
import 'object_inspector_page.dart';

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
  late final ObjectStore _objectStore;
  late final GenericDatabasePageServices _pageServices;
  late final ObjectComputedValueStore _computedStore;
  late final ObjectTypeManagementStore _managementStore;
  late final ObjectGraphQueryStore _graphStore;
  late final DatabaseViewStore _viewStore;
  late final ObjectBoardMoveService _boardMoveService;

  static const _viewCoordinator = GenericObjectViewCoordinator();
  static const _openPresentationHost = ObjectOpenPresentationHost();

  GenericDatabaseDefinitionRecord? _database;
  AppObjectType? _objectType;
  List<AppObject> _objects = const [];
  List<GenericPropertyRecord> _properties = const [];
  List<GenericRecord> _records = const [];
  List<GenericDatabaseDefinitionRecord> _objectTypes = const [];
  Map<int, List<GenericRecord>> _recordsByType = const {};
  Map<int, Map<int, dynamic>> _computedValues = const {};
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
    'relation': 'リレーション',
    'formula': '数式',
    'rollup': 'ロールアップ',
  };

  @override
  void initState() {
    super.initState();
    _store = GenericDatabaseStore(widget.repository.workspaceStore.database);
    _objectStore = ObjectStore(_store);
    _pageServices = GenericDatabasePageServices.fromStores(
      genericStore: _store,
      objectStore: _objectStore,
    );
    _boardMoveService = ObjectBoardMoveService(_objectStore);
    _computedStore = ObjectComputedValueStore(_objectStore);
    _managementStore = ObjectTypeManagementStore(
      genericStore: _store,
      objectStore: _objectStore,
    );
    _graphStore = ObjectGraphQueryStore(_store);
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
    final page = await _pageServices.loader.load(widget.databaseId);
    final database = page?.database;
    final properties = page?.properties ?? const <GenericPropertyRecord>[];
    final records = page?.records ?? const <GenericRecord>[];
    final objectType = page?.objectType;
    final objects = page?.objects ?? const <AppObject>[];
    final objectTypes =
        await _store.listAllDatabases(widget.repository.workspaceId);
    final recordsByType = <int, List<GenericRecord>>{};
    for (final relatedType in objectTypes) {
      // Relation display must resolve all target Objects, not just members of
      // the active collection when its target ObjectType matches this type.
      recordsByType[relatedType.id] = await _store.listRecords(relatedType.id);
    }

    final computedValues = <int, Map<int, dynamic>>{};
    if (objectType != null) {
      final computedProperties = objectType.properties
          .where(
            (property) =>
                property.type == ObjectPropertyType.formula ||
                property.type == ObjectPropertyType.rollup,
          )
          .toList(growable: false);
      for (final object in objects) {
        for (final property in computedProperties) {
          try {
            final value = await _computedStore.evaluate(
              object: object,
              property: property,
            );
            (computedValues[object.id] ??= <int, dynamic>{})[property.id] =
                value;
          } catch (_) {
            (computedValues[object.id] ??= <int, dynamic>{})[property.id] =
                null;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _database = database;
      _objectType = objectType;
      _objects = objects;
      _properties = properties;
      _records = records;
      _objectTypes = objectTypes;
      _recordsByType = recordsByType;
      _computedValues = computedValues;
      if (_selectedRecordId != null &&
          !records.any((record) => record.id == _selectedRecordId)) {
        _selectedRecordId = null;
      }
      _loading = false;
    });
  }

  Future<void> _editDatabaseIdentity() async {
    final database = _database;
    if (database == null) return;
    var name = database.name;
    var icon = database.icon;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('データベースを編集'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: '名前'),
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: icon,
                decoration: const InputDecoration(
                  labelText: 'アイコン',
                  hintText: '例: 📚',
                ),
                onChanged: (value) => icon = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true || name.trim().isEmpty) return;
    try {
      await _managementStore.updateIdentity(
        objectTypeId: database.id,
        name: name,
        icon: icon,
      );
      widget.onDatabaseChanged();
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データベースを更新できませんでした: $error')),
      );
    }
  }

  Future<void> _duplicateDatabase() async {
    final database = _database;
    if (database == null) return;
    try {
      await _managementStore.duplicateSchema(objectTypeId: database.id);
      widget.onDatabaseChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${database.name}」の構造を複製しました')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データベースを複製できませんでした: $error')),
      );
    }
  }

  Future<void> _editCollectionSettings() async {
    try {
      final config = await _pageServices.collectionConfig.load(widget.databaseId);
      if (config == null || !mounted) return;
      final draft = await showDatabaseCollectionSettingsDialog(
        context,
        config: config,
      );
      if (draft == null) return;
      await _pageServices.collectionConfig.save(
        databaseId: widget.databaseId,
        workspaceId: widget.repository.workspaceId,
        targetObjectTypeId: draft.targetObjectTypeId,
        collectionFilter: draft.collectionFilter,
      );
      if (!mounted) return;
      setState(() {
        _activeView = null;
        _selectedRecordId = null;
        _query = '';
      });
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コレクション設定を保存できませんでした: $error')),
      );
    }
  }

  Future<void> _deleteDatabase() async {
    final database = _database;
    if (database == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「${database.name}」を削除しますか？'),
        content: const Text('このデータベース内のObjectとプロパティも削除されます。この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _managementStore.deleteCustomType(database.id);
      if (!mounted) return;
      setState(() {
        _database = null;
        _selectedRecordId = null;
      });
      widget.onDatabaseChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データベースを削除できませんでした: $error')),
      );
    }
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
        supportedLayouts: const ['gallery', 'list', 'table', 'board'],
      );

  DatabasePropertyType _databasePropertyType(String type) => switch (type) {
        'number' => DatabasePropertyType.number,
        'formula' => DatabasePropertyType.number,
        'rollup' => DatabasePropertyType.number,
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
        'formula' => Icons.calculate_outlined,
        'rollup' => Icons.functions,
        'select' => Icons.arrow_drop_down_circle_outlined,
        'multiSelect' => Icons.sell_outlined,
        'checkbox' => Icons.check_box_outlined,
        'date' => Icons.calendar_today_outlined,
        'url' => Icons.link,
        'rating' => Icons.star_outline,
        'relation' => Icons.swap_horiz,
        _ => Icons.text_fields,
      };

  int? _targetTypeId(GenericPropertyRecord property) {
    final value = property.config['targetObjectTypeId'];
    return value is int ? value : int.tryParse('$value');
  }

  List<int> _relationIds(dynamic value) =>
      ObjectRelationValue.fromJson(value).objectIds;

  List<GenericRecord> _relatedRecords(
    GenericPropertyRecord property,
    dynamic value,
  ) {
    final targetTypeId = _targetTypeId(property);
    if (targetTypeId == null) return const [];
    final ids = _relationIds(value).toSet();
    if (ids.isEmpty) return const [];
    return (_recordsByType[targetTypeId] ?? const <GenericRecord>[])
        .where((record) => ids.contains(record.id))
        .toList(growable: false);
  }

  String _relationDisplay(GenericPropertyRecord property, dynamic value) =>
      _relatedRecords(property, value).map((record) => record.title).join(', ');

  dynamic _valueFor(GenericRecord record, GenericPropertyRecord property) {
    if (property.type == 'formula' || property.type == 'rollup') {
      return _computedValues[record.id]?[property.id];
    }
    return record.values[property.id];
  }

  dynamic _projectedValueFor(AppObject object, int? propertyId) {
    if (propertyId == null) return object.title;
    final computed = _computedValues[object.id];
    if (computed != null && computed.containsKey(propertyId)) {
      return computed[propertyId];
    }
    return object.values[propertyId];
  }

  GenericObjectViewProjection? get _viewProjection {
    final active = _activeView;
    if (active == null) return null;
    return _viewCoordinator.project(
      objects: _objects,
      records: _records,
      view: active,
      valueResolver: _projectedValueFor,
    );
  }

  List<GenericPropertyRecord> get _orderedVisibleProperties {
    final order = _activeView?.propertyOrder ?? const <String>[];
    final visible = (_activeView?.visibleProperties ?? const <String>[]).toSet();
    final byKey = {
      for (final property in _properties) 'p:${property.id}': property,
    };
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

  GenericRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedRecordId) return record;
    }
    return null;
  }

  Future<void> _openDatabaseObject(int objectId) async {
    final activeView = _activeView;
    final objectTypeId = _objectType?.id;
    if (activeView == null || objectTypeId == null) {
      if (mounted) setState(() => _selectedRecordId = objectId);
      return;
    }

    if (_selectedRecordId != null && mounted) {
      setState(() => _selectedRecordId = null);
    }

    final mode = await _openPresentationHost.openResolved(
      context: context,
      resolver: _pageServices.openPresentation,
      view: activeView,
      objectTypeId: objectTypeId,
      onSidePeek: () {
        if (mounted) setState(() => _selectedRecordId = objectId);
      },
      detailBuilder: (_) => ObjectInspectorPage(
        store: _store,
        objectStore: _objectStore,
        objectId: objectId,
      ),
    );

    if (mounted && mode != ObjectOpenMode.sidePeek) {
      await _reload();
    }
  }

  Future<void> _selectView(DatabaseViewConfig view) async {
    setState(() {
      _activeView = view;
      _query = '${view.filters['query'] ?? ''}';
    });
  }

  Future<void> _persistView(DatabaseViewConfig next) async {
    await _viewStore.updateView(next);
    if (!mounted) return;
    setState(() {
      _activeView = next;
      _query = '${next.filters['query'] ?? ''}';
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
    await _persistView(next);
  }

  Future<String?> _askObjectTitle() async {
    var title = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新規Object'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: '名前'),
          onChanged: (value) => title = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, title.trim()),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    final normalized = result?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _createRecord(String title) async {
    try {
      final id = await _pageServices.creator.create(
        databaseId: widget.databaseId,
        title: title,
      );
      await _reload();
      if (!mounted) return;
      if (_records.any((record) => record.id == id)) {
        setState(() => _selectedRecordId = id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objectを作成しましたが、現在のコレクション条件には一致しません。'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Objectを作成できませんでした: $error')),
      );
    }
  }

  Future<void> _createProperty() async {
    final sourceObjectTypeId = _objectType?.id;
    if (sourceObjectTypeId == null) return;
    var name = '';
    var type = 'text';
    var optionsText = '';
    int? targetObjectTypeId;
    var multipleRelations = true;
    var formulaExpression = '';
    int? rollupRelationPropertyId;
    int? rollupTargetPropertyId;
    var rollupAggregation = 'count';
    var rollupTargetProperties = <GenericPropertyRecord>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final relationProperties = _properties
              .where((property) => property.type == 'relation')
              .toList(growable: false);
          final numericProperties = _properties
              .where(
                (property) =>
                    property.type == 'number' || property.type == 'rating',
              )
              .toList(growable: false);
          final canSave = switch (type) {
            'relation' => targetObjectTypeId != null,
            'formula' => formulaExpression.trim().isNotEmpty,
            'rollup' => rollupRelationPropertyId != null &&
                (rollupAggregation == 'count' ||
                    rollupTargetPropertyId != null),
            _ => true,
          };

          return AlertDialog(
            title: const Text('プロパティを追加'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
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
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setLocalState(() {
                        type = value ?? 'text';
                        if (type != 'relation') targetObjectTypeId = null;
                        if (type != 'rollup') {
                          rollupRelationPropertyId = null;
                          rollupTargetPropertyId = null;
                          rollupTargetProperties = <GenericPropertyRecord>[];
                        }
                      }),
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
                    if (type == 'relation') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: targetObjectTypeId,
                        decoration: const InputDecoration(labelText: '関連先'),
                        items: _objectTypes
                            .map(
                              (objectType) => DropdownMenuItem(
                                value: objectType.id,
                                child: Text('${objectType.icon} ${objectType.name}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setLocalState(() => targetObjectTypeId = value),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('複数選択'),
                        subtitle: Text(
                          multipleRelations
                              ? '複数のObjectを関連付けできます'
                              : '1つのObjectだけ関連付けます',
                        ),
                        value: multipleRelations,
                        onChanged: (value) =>
                            setLocalState(() => multipleRelations = value),
                      ),
                    ],
                    if (type == 'formula') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: '数式',
                          hintText: '例: {12} * 2 + 100',
                        ),
                        onChanged: (value) =>
                            setLocalState(() => formulaExpression = value),
                      ),
                      if (numericProperties.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '数値プロパティの参照',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: numericProperties
                                .map(
                                  (property) => InputChip(
                                    label: Text('${property.name} = {${property.id}}'),
                                    onPressed: () {},
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                    if (type == 'rollup') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: rollupRelationPropertyId,
                        decoration: const InputDecoration(labelText: 'Relation'),
                        items: relationProperties
                            .map(
                              (property) => DropdownMenuItem(
                                value: property.id,
                                child: Text(property.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          rollupRelationPropertyId = value;
                          rollupTargetPropertyId = null;
                          rollupTargetProperties = <GenericPropertyRecord>[];
                          if (value != null) {
                            final relation = relationProperties
                                .firstWhere((property) => property.id == value);
                            final targetId = _targetTypeId(relation);
                            if (targetId != null) {
                              final targetProperties =
                                  await _store.listProperties(targetId);
                              rollupTargetProperties = targetProperties
                                  .where(
                                    (property) =>
                                        property.type == 'number' ||
                                        property.type == 'rating',
                                  )
                                  .toList(growable: false);
                            }
                          }
                          setLocalState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: rollupAggregation,
                        decoration: const InputDecoration(labelText: '集計'),
                        items: const [
                          DropdownMenuItem(value: 'count', child: Text('件数')),
                          DropdownMenuItem(value: 'sum', child: Text('合計')),
                          DropdownMenuItem(value: 'average', child: Text('平均')),
                          DropdownMenuItem(value: 'min', child: Text('最小')),
                          DropdownMenuItem(value: 'max', child: Text('最大')),
                        ],
                        onChanged: (value) => setLocalState(() {
                          rollupAggregation = value ?? 'count';
                          if (rollupAggregation == 'count') {
                            rollupTargetPropertyId = null;
                          }
                        }),
                      ),
                      if (rollupAggregation != 'count') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: rollupTargetPropertyId,
                          decoration: const InputDecoration(labelText: '対象プロパティ'),
                          items: rollupTargetProperties
                              .map(
                                (property) => DropdownMenuItem(
                                  value: property.id,
                                  child: Text(property.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setLocalState(
                            () => rollupTargetPropertyId = value,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: canSave
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || name.trim().isEmpty) return;

    final options = optionsText
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    try {
      if (type == 'relation') {
        await _objectStore.createRelationProperty(
          objectTypeId: sourceObjectTypeId,
          name: name.trim(),
          targetObjectTypeId: targetObjectTypeId!,
          multiple: multipleRelations,
        );
      } else if (type == 'formula') {
        await _computedStore.createFormulaProperty(
          objectTypeId: sourceObjectTypeId,
          name: name.trim(),
          expression: formulaExpression,
        );
      } else if (type == 'rollup') {
        await _computedStore.createRollupProperty(
          objectTypeId: sourceObjectTypeId,
          name: name.trim(),
          relationPropertyId: rollupRelationPropertyId!,
          targetPropertyId: rollupTargetPropertyId,
          aggregation: rollupAggregation,
        );
      } else {
        await _store.createProperty(
          databaseId: sourceObjectTypeId,
          name: name.trim(),
          type: type,
          config: options.isEmpty ? const {} : {'options': options},
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プロパティを追加できませんでした: $error')),
      );
      return;
    }

    await _reload();

    final active = _activeView;
    if (active != null && _properties.isNotEmpty) {
      final key = 'p:${_properties.last.id}';
      await _saveView(
        propertyOrder: [...active.propertyOrder, key],
        visibleProperties: [...active.visibleProperties, key],
      );
    }
  }

  Future<void> _reorderProperties(List<GenericPropertyRecord> next) async {
    await _saveView(
      propertyOrder: next.map((property) => 'p:${property.id}').toList(),
    );
  }

  String _displayValue(GenericPropertyRecord property, dynamic value) {
    if (property.type == 'relation') return _relationDisplay(property, value);
    return formatDatabasePropertyValue(_databasePropertyType(property.type), value);
  }

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
              onTap: () => _openDatabaseObject(record.id),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ..._orderedVisibleProperties.take(4).map(
                          (property) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '${property.name}: ${_displayValue(property, _valueFor(record, property))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
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
                        .map(
                          (property) =>
                              _displayValue(property, _valueFor(record, property)),
                        )
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () => _openDatabaseObject(record.id),
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
              ...properties.map(
                (property) => DataColumn(label: Text(property.name)),
              ),
            ],
            rows: records
                .map(
                  (record) => DataRow(
                    selected: record.id == _selectedRecordId,
                    onSelectChanged: (_) => _openDatabaseObject(record.id),
                    cells: [
                      DataCell(Text(record.title)),
                      ...properties.map(
                        (property) => DataCell(
                          Text(
                            _displayValue(property, _valueFor(record, property)),
                          ),
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

  Widget _board(GenericObjectViewProjection projection) {
    final objectType = _objectType;
    final groupRule = projection.objectProjection.groupRule;
    ObjectPropertyDefinition? groupProperty;
    if (objectType != null && groupRule != null) {
      for (final property in objectType.properties) {
        if (property.id == groupRule.propertyId) {
          groupProperty = property;
          break;
        }
      }
    }
    final movable = groupProperty != null &&
        _boardMoveService.planner.canMove(groupProperty);
    final creatable = groupProperty != null &&
        _pageServices.creator.boardCreate.planner.canPreset(groupProperty);

    return ObjectBoardView(
      groups: projection.objectProjection.groups,
      onObjectTap: (object) => _openDatabaseObject(object.id),
      onMoveObject: !movable
          ? null
          : (object, sourceGroup, targetGroup) async {
              try {
                await _boardMoveService.move(
                  object: object,
                  property: groupProperty!,
                  sourceGroup: sourceGroup,
                  targetGroup: targetGroup,
                );
                await _reload();
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('カードを移動できませんでした: $error')),
                );
              }
            },
      onCreateInGroup: !creatable
          ? null
          : (targetGroup) async {
              final title = await _askObjectTitle();
              if (title == null) return;
              try {
                final id = await _pageServices.creator.createInGroup(
                  databaseId: widget.databaseId,
                  title: title,
                  groupProperty: groupProperty!,
                  targetGroup: targetGroup,
                );
                await _reload();
                if (!mounted) return;
                if (_records.any((record) => record.id == id)) {
                  setState(() => _selectedRecordId = id);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Objectを作成しましたが、現在のコレクション条件には一致しません。',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Objectを作成できませんでした: $error')),
                );
              }
            },
      cardSubtitleBuilder: (object) {
        final record = _records
            .where((candidate) => candidate.id == object.id)
            .firstOrNull;
        if (record == null) return null;
        final values = _orderedVisibleProperties
            .map((property) =>
                _displayValue(property, _valueFor(record, property)))
            .where((value) => value.isNotEmpty)
            .take(2)
            .toList(growable: false);
        return values.isEmpty ? null : values.join(' · ');
      },
    );
  }

  Future<void> _editRelation(
    GenericRecord record,
    GenericPropertyRecord property,
  ) async {
    final objectType = _objectType;
    if (objectType == null) return;
    ObjectPropertyDefinition? objectProperty;
    for (final candidate in objectType.properties) {
      if (candidate.id == property.id) {
        objectProperty = candidate;
        break;
      }
    }
    if (objectProperty == null || !objectProperty.isRelation) return;

    try {
      final selection = await _pageServices.relationEditor.load(
        workspaceId: widget.repository.workspaceId,
        sourceObjectId: record.id,
        property: objectProperty,
      );
      if (!mounted) return;
      final selectedIds = selection.selectedObjectIds.toSet();
      var query = '';

      final result = await showDialog<Set<int>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocalState) {
            final normalized = query.trim().toLowerCase();
            final visible = selection.candidates
                .where(
                  (candidate) => normalized.isEmpty ||
                      candidate.title.toLowerCase().contains(normalized),
                )
                .toList(growable: false);
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              title: Row(
                children: [
                  Expanded(child: Text(property.name)),
                  Text(
                    '${selectedIds.length}件選択',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                height: 470,
                child: Column(
                  children: [
                    if (selection.missingTargetObjectIds.isNotEmpty ||
                        selection.hasCardinalityViolation)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          [
                            if (selection.missingTargetObjectIds.isNotEmpty)
                              '見つからないObject: ${selection.missingTargetObjectIds.join(', ')}',
                            if (selection.hasCardinalityViolation)
                              '単一Relationに複数の値が保存されています。明示的に選び直して保存してください。',
                          ].join('\n'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Objectを検索',
                        ),
                        onChanged: (value) =>
                            setLocalState(() => query = value),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('該当するObjectがありません'))
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final candidate = visible[index];
                                final selected = selectedIds.contains(candidate.id);
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    selection.property.allowsMultipleRelations
                                        ? (selected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank)
                                        : (selected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked),
                                    size: 19,
                                  ),
                                  title: Text(candidate.title),
                                  onTap: () => setLocalState(() {
                                    if (selected) {
                                      selectedIds.remove(candidate.id);
                                    } else {
                                      if (!selection
                                          .property.allowsMultipleRelations) {
                                        selectedIds.clear();
                                      }
                                      selectedIds.add(candidate.id);
                                    }
                                  }),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => setLocalState(selectedIds.clear),
                  child: const Text('クリア'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, selectedIds),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        ),
      );
      if (result == null) return;

      await _pageServices.relationEditor.save(
        context: selection,
        selectedObjectIds: result,
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relationを更新できませんでした: $error')),
      );
    }
  }

  Future<void> _editValue(
    GenericRecord record,
    GenericPropertyRecord property,
  ) async {
    if (property.type == 'formula' || property.type == 'rollup') return;
    final current = record.values[property.id];
    if (property.type == 'relation') {
      await _editRelation(record, property);
      return;
    }
    if (property.type == 'checkbox') {
      await _store.setValue(
        recordId: record.id,
        propertyId: property.id,
        value: current != true,
      );
      await _reload();
      return;
    }
    if (property.type == 'rating') {
      final next = ((current is num ? current.toInt() : 0) + 1) % 6;
      await _store.setValue(
        recordId: record.id,
        propertyId: property.id,
        value: next,
      );
      await _reload();
      return;
    }
    if (property.type == 'select') {
      final options =
          (property.config['options'] as List?)?.whereType<String>().toList() ??
              const <String>[];
      final selected = await showMenu<String>(
        context: context,
        position: const RelativeRect.fromLTRB(300, 220, 300, 0),
        items: options
            .map(
              (value) => PopupMenuItem(value: value, child: Text(value)),
            )
            .toList(),
      );
      if (selected != null) {
        await _store.setValue(
          recordId: record.id,
          propertyId: property.id,
          value: selected,
        );
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;

    dynamic parsed = result;
    if (property.type == 'number') parsed = num.tryParse(result);
    if (property.type == 'multiSelect') {
      parsed = result
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    await _store.setValue(
      recordId: record.id,
      propertyId: property.id,
      value: parsed,
    );
    await _reload();
  }

  Future<void> _openObject(int objectId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ObjectInspectorPage(
          store: _store,
          objectStore: _objectStore,
          objectId: objectId,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Widget _relationValue(
    GenericRecord record,
    GenericPropertyRecord property,
  ) {
    final related = _relatedRecords(property, record.values[property.id]);
    if (related.isEmpty) {
      return Text(
        'なし',
        style: TextStyle(
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: related
          .map(
            (item) => ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.link, size: 14),
              label: Text(item.title),
              onPressed: () => _openObject(item.id),
            ),
          )
          .toList(),
    );
  }

  Widget _backlinks(GenericRecord record) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<ObjectGraphBacklinkRecord>>(
      key: ValueKey('backlinks:${record.id}:${record.updatedAt}'),
      future: _graphStore.backlinks(record.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }
        final items = snapshot.data ?? const <ObjectGraphBacklinkRecord>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.link, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 7),
                Text(
                  'Backlinks  ${items.length}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ...items.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  item.sourceObjectTypeIcon,
                  style: const TextStyle(fontSize: 17),
                ),
                title: Text(item.sourceTitle),
                subtitle: Text(
                  '${item.sourceObjectTypeName} · ${item.propertyName}',
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _openObject(item.sourceObjectId),
              ),
            ),
          ],
        );
      },
    );
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
                const Text(
                  '詳細',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  key: ValueKey('side-peek-open-full-page-${record.id}'),
                  tooltip: 'フルページで開く',
                  icon: const Icon(Icons.open_in_full, size: 18),
                  onPressed: () => _openObject(record.id),
                ),
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
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
                    final value = _valueFor(record, property);
                    final computed =
                        property.type == 'formula' || property.type == 'rollup';
                    return ReorderableDragStartListener(
                      key: ValueKey(property.id),
                      index: index,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: computed ? null : () => _editValue(record, property),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 15,
                                  color: scheme.onSurfaceVariant.withValues(alpha: .55),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  _propertyIcon(property.type),
                                  size: 17,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 9),
                              SizedBox(
                                width: 120,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          property.name,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      if (computed)
                                        Icon(
                                          Icons.lock_outline,
                                          size: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: property.type == 'relation'
                                    ? _relationValue(record, property)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          _displayValue(property, value).isEmpty
                                              ? 'なし'
                                              : _displayValue(property, value),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: _displayValue(property, value).isEmpty
                                                ? scheme.onSurfaceVariant
                                                    .withValues(alpha: .55)
                                                : scheme.onSurface,
                                          ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _createProperty,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('プロパティを追加'),
                  ),
                ),
                _backlinks(record),
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
    if (database == null) {
      return const Center(child: Text('データベースが見つかりません'));
    }
    final projection = _viewProjection;
    final records = projection?.records ?? _records;
    final selected = _selectedRecord;
    final activeView = _activeView;
    final layout = activeView?.layoutType ?? 'table';

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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      onSaved: (value) async {
                        await _managementStore.updateIdentity(
                          objectTypeId: database.id,
                          name: value,
                        );
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
                  PopupMenuButton<String>(
                    tooltip: 'データベース設定',
                    icon: const Icon(Icons.more_horiz, size: 19),
                    onSelected: (value) {
                      if (value == 'collection') _editCollectionSettings();
                      if (value == 'edit') _editDatabaseIdentity();
                      if (value == 'duplicate') _duplicateDatabase();
                      if (value == 'delete') _deleteDatabase();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'collection',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.filter_alt_outlined, size: 18),
                          title: Text('コレクション設定'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit_outlined, size: 18),
                          title: Text('名前・アイコンを編集'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.copy_outlined, size: 18),
                          title: Text('構造を複製'),
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline, size: 18),
                          title: Text('削除'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          DatabaseViewTabs(
            store: _viewStore,
            definition: _definition,
            workspaceId: widget.repository.workspaceId,
            activeViewId: activeView?.id,
            onSelected: _selectView,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 7),
            child: Row(
              children: [
                if (activeView != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ObjectViewToolbar(
                        view: activeView,
                        properties: _objectType?.properties ?? const [],
                        onViewChanged: (next) {
                          _persistView(next);
                        },
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                SizedBox(
                  width: 250,
                  height: 36,
                  child: TextFormField(
                    key: ValueKey('${activeView?.id}:$_query'),
                    initialValue: _query,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 17),
                      hintText: '検索',
                    ),
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
                    'board' when projection != null => _board(projection),
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
