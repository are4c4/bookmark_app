import 'package:flutter/material.dart';

import '../domain/object_model.dart';
import '../domain/object_query.dart';

class ObjectQueryDraft {
  const ObjectQueryDraft({
    required this.filters,
    required this.sorts,
  });

  final List<ObjectFilterRule> filters;
  final List<ObjectSortRule> sorts;
}

Future<ObjectQueryDraft?> showObjectQueryDialog(
  BuildContext context, {
  required List<ObjectPropertyDefinition> properties,
  List<ObjectFilterRule> initialFilters = const <ObjectFilterRule>[],
  List<ObjectSortRule> initialSorts = const <ObjectSortRule>[],
}) {
  return showDialog<ObjectQueryDraft>(
    context: context,
    builder: (_) => ObjectQueryDialog(
      properties: properties,
      initialFilters: initialFilters,
      initialSorts: initialSorts,
    ),
  );
}

class ObjectQueryDialog extends StatefulWidget {
  const ObjectQueryDialog({
    super.key,
    required this.properties,
    this.initialFilters = const <ObjectFilterRule>[],
    this.initialSorts = const <ObjectSortRule>[],
  });

  final List<ObjectPropertyDefinition> properties;
  final List<ObjectFilterRule> initialFilters;
  final List<ObjectSortRule> initialSorts;

  @override
  State<ObjectQueryDialog> createState() => _ObjectQueryDialogState();
}

class _ObjectQueryDialogState extends State<ObjectQueryDialog> {
  late List<_EditableFilter> _filters;
  late List<ObjectSortRule> _sorts;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters
        .map((rule) => _EditableFilter.fromRule(rule))
        .toList(growable: true);
    _sorts = [...widget.initialSorts];
  }

  List<ObjectFilterRule> get _builtFilters => _filters
      .map((filter) => filter.toRule())
      .whereType<ObjectFilterRule>()
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('フィルターと並び替え'),
      content: SizedBox(
        width: 680,
        height: 560,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'フィルター'),
                  Tab(text: '並び替え'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _filterTab(),
                    _sortTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ObjectQueryDraft(filters: _builtFilters, sorts: [..._sorts]),
          ),
          child: const Text('適用'),
        ),
      ],
    );
  }

  Widget _filterTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        if (_filters.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('フィルターはありません')),
          ),
        ...List.generate(_filters.length, (index) => _filterRow(index)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _filters.add(
                _EditableFilter(
                  propertyId: null,
                  operator: ObjectFilterOperator.contains,
                  value: '',
                  revision: 0,
                ),
              );
            }),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('フィルターを追加'),
          ),
        ),
      ],
    );
  }

  Widget _filterRow(int index) {
    final filter = _filters[index];
    final property = _propertyById(filter.propertyId);
    final operators = _operatorsFor(property);
    if (!operators.contains(filter.operator)) {
      filter.operator = operators.first;
    }
    final needsValue = !_valueLessOperators.contains(filter.operator);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<int?>(
                initialValue: filter.propertyId,
                decoration: const InputDecoration(labelText: 'プロパティ'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('名前')),
                  ...widget.properties.map(
                    (property) => DropdownMenuItem<int?>(
                      value: property.id,
                      child: Text(property.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  filter.propertyId = value;
                  final nextOperators = _operatorsFor(_propertyById(value));
                  if (!nextOperators.contains(filter.operator)) {
                    filter.operator = nextOperators.first;
                  }
                  filter.value = '';
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<ObjectFilterOperator>(
                initialValue: filter.operator,
                decoration: const InputDecoration(labelText: '条件'),
                items: operators
                    .map((operator) => DropdownMenuItem(
                          value: operator,
                          child: Text(_operatorLabel(operator)),
                        ))
                    .toList(growable: false),
                onChanged: (value) => setState(() {
                  if (value != null) filter.operator = value;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: needsValue
                  ? _filterValueEditor(filter, property)
                  : const SizedBox(height: 48),
            ),
            IconButton(
              tooltip: '削除',
              onPressed: () => setState(() => _filters.removeAt(index)),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterValueEditor(
    _EditableFilter filter,
    ObjectPropertyDefinition? property,
  ) {
    if (property?.type == ObjectPropertyType.checkbox) {
      final checked = filter.value == true || '${filter.value}' == 'true';
      return DropdownButtonFormField<bool>(
        initialValue: checked,
        decoration: const InputDecoration(labelText: '値'),
        items: const [
          DropdownMenuItem(value: true, child: Text('オン')),
          DropdownMenuItem(value: false, child: Text('オフ')),
        ],
        onChanged: (value) => setState(() => filter.value = value ?? false),
      );
    }

    return TextFormField(
      key: ValueKey(
        'filter-value-${filter.propertyId}-${filter.operator.name}-${filter.revision}',
      ),
      initialValue: _displayFilterValue(filter.value),
      decoration: InputDecoration(
        labelText: '値',
        hintText: _filterValueHint(property, filter.operator),
      ),
      onChanged: (value) => filter.value = _parseFilterValue(property, value),
    );
  }

  Widget _sortTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        if (_sorts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('並び替えはありません')),
          ),
        ...List.generate(_sorts.length, (index) => _sortRow(index)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _sorts.add(
                const ObjectSortRule(
                  propertyId: null,
                  direction: ObjectSortDirection.ascending,
                ),
              );
            }),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('並び替えを追加'),
          ),
        ),
      ],
    );
  }

  Widget _sortRow(int index) {
    final sort = _sorts[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: sort.propertyId,
                decoration: const InputDecoration(labelText: 'プロパティ'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('名前')),
                  ...widget.properties.map(
                    (property) => DropdownMenuItem<int?>(
                      value: property.id,
                      child: Text(property.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _sorts[index] = ObjectSortRule(
                    propertyId: value,
                    direction: sort.direction,
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<ObjectSortDirection>(
                initialValue: sort.direction,
                decoration: const InputDecoration(labelText: '順序'),
                items: const [
                  DropdownMenuItem(
                    value: ObjectSortDirection.ascending,
                    child: Text('昇順'),
                  ),
                  DropdownMenuItem(
                    value: ObjectSortDirection.descending,
                    child: Text('降順'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  if (value == null) return;
                  _sorts[index] = ObjectSortRule(
                    propertyId: sort.propertyId,
                    direction: value,
                  );
                }),
              ),
            ),
            IconButton(
              tooltip: '削除',
              onPressed: () => setState(() => _sorts.removeAt(index)),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  ObjectPropertyDefinition? _propertyById(int? id) {
    if (id == null) return null;
    for (final property in widget.properties) {
      if (property.id == id) return property;
    }
    return null;
  }

  List<ObjectFilterOperator> _operatorsFor(ObjectPropertyDefinition? property) {
    if (property == null ||
        property.type == ObjectPropertyType.text ||
        property.type == ObjectPropertyType.url ||
        property.type == ObjectPropertyType.select) {
      return const [
        ObjectFilterOperator.contains,
        ObjectFilterOperator.notContains,
        ObjectFilterOperator.equals,
        ObjectFilterOperator.notEquals,
        ObjectFilterOperator.isEmpty,
        ObjectFilterOperator.isNotEmpty,
      ];
    }
    if (property.type == ObjectPropertyType.number ||
        property.type == ObjectPropertyType.rating ||
        property.type == ObjectPropertyType.formula ||
        property.type == ObjectPropertyType.rollup) {
      return const [
        ObjectFilterOperator.equals,
        ObjectFilterOperator.notEquals,
        ObjectFilterOperator.greaterThan,
        ObjectFilterOperator.greaterThanOrEqual,
        ObjectFilterOperator.lessThan,
        ObjectFilterOperator.lessThanOrEqual,
        ObjectFilterOperator.isEmpty,
        ObjectFilterOperator.isNotEmpty,
      ];
    }
    if (property.type == ObjectPropertyType.date) {
      return const [
        ObjectFilterOperator.equals,
        ObjectFilterOperator.before,
        ObjectFilterOperator.after,
        ObjectFilterOperator.isEmpty,
        ObjectFilterOperator.isNotEmpty,
      ];
    }
    if (property.type == ObjectPropertyType.multiSelect ||
        property.type == ObjectPropertyType.objectRelation) {
      return const [
        ObjectFilterOperator.containsAny,
        ObjectFilterOperator.containsAll,
        ObjectFilterOperator.isEmpty,
        ObjectFilterOperator.isNotEmpty,
      ];
    }
    return const [
      ObjectFilterOperator.equals,
      ObjectFilterOperator.notEquals,
      ObjectFilterOperator.isEmpty,
      ObjectFilterOperator.isNotEmpty,
    ];
  }

  String _operatorLabel(ObjectFilterOperator operator) => switch (operator) {
        ObjectFilterOperator.equals => '等しい',
        ObjectFilterOperator.notEquals => '等しくない',
        ObjectFilterOperator.contains => '含む',
        ObjectFilterOperator.notContains => '含まない',
        ObjectFilterOperator.isEmpty => '空',
        ObjectFilterOperator.isNotEmpty => '空ではない',
        ObjectFilterOperator.greaterThan => 'より大きい',
        ObjectFilterOperator.greaterThanOrEqual => '以上',
        ObjectFilterOperator.lessThan => 'より小さい',
        ObjectFilterOperator.lessThanOrEqual => '以下',
        ObjectFilterOperator.before => 'より前',
        ObjectFilterOperator.after => 'より後',
        ObjectFilterOperator.containsAny => 'いずれかを含む',
        ObjectFilterOperator.containsAll => 'すべてを含む',
      };

  String _filterValueHint(
    ObjectPropertyDefinition? property,
    ObjectFilterOperator operator,
  ) {
    if (operator == ObjectFilterOperator.containsAny ||
        operator == ObjectFilterOperator.containsAll) {
      return property?.type == ObjectPropertyType.objectRelation
          ? 'Object IDをカンマ区切り'
          : '値をカンマ区切り';
    }
    if (property?.type == ObjectPropertyType.date) return '2026-09-02';
    return '値を入力';
  }

  dynamic _parseFilterValue(ObjectPropertyDefinition? property, String value) {
    if (property?.type == ObjectPropertyType.number ||
        property?.type == ObjectPropertyType.rating ||
        property?.type == ObjectPropertyType.formula ||
        property?.type == ObjectPropertyType.rollup) {
      return num.tryParse(value) ?? value;
    }
    if (property?.type == ObjectPropertyType.multiSelect) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (property?.type == ObjectPropertyType.objectRelation) {
      return value
          .split(',')
          .map((item) => int.tryParse(item.trim()))
          .whereType<int>()
          .toList(growable: false);
    }
    return value;
  }

  String _displayFilterValue(dynamic value) {
    if (value is Iterable) return value.join(', ');
    return value == null ? '' : '$value';
  }

  static const _valueLessOperators = <ObjectFilterOperator>{
    ObjectFilterOperator.isEmpty,
    ObjectFilterOperator.isNotEmpty,
  };
}

class _EditableFilter {
  _EditableFilter({
    required this.propertyId,
    required this.operator,
    required this.value,
    this.revision = 0,
  });

  factory _EditableFilter.fromRule(ObjectFilterRule rule) => _EditableFilter(
        propertyId: rule.propertyId,
        operator: rule.operator,
        value: rule.value,
      );

  int? propertyId;
  ObjectFilterOperator operator;
  dynamic value;
  int revision;

  ObjectFilterRule? toRule() => ObjectFilterRule(
        propertyId: propertyId,
        operator: operator,
        value: value,
      );
}
