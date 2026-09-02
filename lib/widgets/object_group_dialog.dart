import 'package:flutter/material.dart';

import '../domain/object_group.dart';
import '../domain/object_model.dart';

class ObjectGroupDraft {
  const ObjectGroupDraft({required this.rule});

  final ObjectGroupRule? rule;
}

Future<ObjectGroupDraft?> showObjectGroupDialog(
  BuildContext context, {
  required List<ObjectPropertyDefinition> properties,
  ObjectGroupRule? initialRule,
}) {
  return showDialog<ObjectGroupDraft>(
    context: context,
    builder: (_) => ObjectGroupDialog(
      properties: properties,
      initialRule: initialRule,
    ),
  );
}

class ObjectGroupDialog extends StatefulWidget {
  const ObjectGroupDialog({
    super.key,
    required this.properties,
    this.initialRule,
  });

  final List<ObjectPropertyDefinition> properties;
  final ObjectGroupRule? initialRule;

  @override
  State<ObjectGroupDialog> createState() => _ObjectGroupDialogState();
}

class _ObjectGroupDialogState extends State<ObjectGroupDialog> {
  int? _propertyId;
  bool _includeEmpty = true;

  List<ObjectPropertyDefinition> get _groupableProperties => widget.properties
      .where(_isGroupable)
      .toList(growable: false)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  void initState() {
    super.initState();
    _propertyId = widget.initialRule?.propertyId;
    _includeEmpty = widget.initialRule?.includeEmpty ?? true;
    if (_propertyId != null &&
        !_groupableProperties.any((property) => property.id == _propertyId)) {
      _propertyId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('グループ化'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int?>(
              initialValue: _propertyId,
              decoration: const InputDecoration(labelText: 'プロパティ'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('グループ化しない'),
                ),
                ..._groupableProperties.map(
                  (property) => DropdownMenuItem<int?>(
                    value: property.id,
                    child: Row(
                      children: [
                        Icon(_iconFor(property.type), size: 17),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            property.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _propertyId = value),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _includeEmpty,
              contentPadding: EdgeInsets.zero,
              title: const Text('未設定グループを表示'),
              subtitle: const Text('値がないObjectを「未設定」にまとめます'),
              onChanged: _propertyId == null
                  ? null
                  : (value) => setState(() => _includeEmpty = value ?? true),
            ),
            if (_propertyId != null) ...[
              const SizedBox(height: 8),
              Text(
                _hintFor(_selectedProperty),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            final propertyId = _propertyId;
            Navigator.pop(
              context,
              ObjectGroupDraft(
                rule: propertyId == null
                    ? null
                    : ObjectGroupRule(
                        propertyId: propertyId,
                        includeEmpty: _includeEmpty,
                      ),
              ),
            );
          },
          child: const Text('適用'),
        ),
      ],
    );
  }

  ObjectPropertyDefinition? get _selectedProperty {
    final id = _propertyId;
    if (id == null) return null;
    for (final property in _groupableProperties) {
      if (property.id == id) return property;
    }
    return null;
  }

  bool _isGroupable(ObjectPropertyDefinition property) => switch (property.type) {
        ObjectPropertyType.title ||
        ObjectPropertyType.image ||
        ObjectPropertyType.file ||
        ObjectPropertyType.createdTime ||
        ObjectPropertyType.updatedTime => false,
        _ => true,
      };

  String _hintFor(ObjectPropertyDefinition? property) {
    if (property == null) return '';
    return switch (property.type) {
      ObjectPropertyType.multiSelect =>
        '複数の値を持つObjectは複数のグループに表示されます。',
      ObjectPropertyType.objectRelation =>
        '複数Relationの場合、Objectは関連先ごとのグループに表示されます。',
      ObjectPropertyType.formula || ObjectPropertyType.rollup =>
        '計算結果でグループ化できますが、Board上のドラッグ移動では値を変更できません。',
      _ => 'このプロパティの値ごとにObjectをグループ化します。',
    };
  }

  IconData _iconFor(ObjectPropertyType type) => switch (type) {
        ObjectPropertyType.text => Icons.text_fields,
        ObjectPropertyType.number => Icons.numbers,
        ObjectPropertyType.checkbox => Icons.check_box_outlined,
        ObjectPropertyType.date => Icons.calendar_today_outlined,
        ObjectPropertyType.url => Icons.link,
        ObjectPropertyType.select => Icons.arrow_drop_down_circle_outlined,
        ObjectPropertyType.multiSelect => Icons.sell_outlined,
        ObjectPropertyType.objectRelation => Icons.swap_horiz,
        ObjectPropertyType.rating => Icons.star_outline,
        ObjectPropertyType.formula => Icons.calculate_outlined,
        ObjectPropertyType.rollup => Icons.functions,
        _ => Icons.view_column_outlined,
      };
}
