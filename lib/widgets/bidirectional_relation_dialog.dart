import 'package:flutter/material.dart';

import '../domain/object_model.dart';

class BidirectionalRelationDraft {
  const BidirectionalRelationDraft({
    required this.sourceName,
    required this.targetObjectTypeId,
    required this.inverseName,
    required this.sourceMultiple,
    required this.inverseMultiple,
  });

  final String sourceName;
  final int targetObjectTypeId;
  final String inverseName;
  final bool sourceMultiple;
  final bool inverseMultiple;
}

Future<BidirectionalRelationDraft?> showBidirectionalRelationDialog(
  BuildContext context, {
  required AppObjectType sourceType,
  required List<AppObjectType> targetTypes,
}) {
  return showDialog<BidirectionalRelationDraft>(
    context: context,
    builder: (_) => BidirectionalRelationDialog(
      sourceType: sourceType,
      targetTypes: targetTypes,
    ),
  );
}

class BidirectionalRelationDialog extends StatefulWidget {
  const BidirectionalRelationDialog({
    super.key,
    required this.sourceType,
    required this.targetTypes,
  });

  final AppObjectType sourceType;
  final List<AppObjectType> targetTypes;

  @override
  State<BidirectionalRelationDialog> createState() =>
      _BidirectionalRelationDialogState();
}

class _BidirectionalRelationDialogState
    extends State<BidirectionalRelationDialog> {
  String _sourceName = '';
  String _inverseName = '';
  int? _targetObjectTypeId;
  bool _sourceMultiple = true;
  bool _inverseMultiple = true;

  bool get _canSave =>
      _sourceName.trim().isNotEmpty &&
      _inverseName.trim().isNotEmpty &&
      _targetObjectTypeId != null;

  @override
  Widget build(BuildContext context) {
    final targetTypes = widget.targetTypes
        .where((type) => type.kind == ObjectTypeKind.custom)
        .toList(growable: false);

    return AlertDialog(
      title: const Text('双方向リレーションを追加'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.sourceType.icon} ${widget.sourceType.name}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'こちら側のプロパティ名',
                  hintText: '例: 著者',
                ),
                onChanged: (value) => setState(() => _sourceName = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _targetObjectTypeId,
                decoration: const InputDecoration(labelText: '関連先Object Type'),
                items: targetTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type.id,
                        child: Text('${type.icon} ${type.name}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _targetObjectTypeId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '関連先に作る逆側プロパティ名',
                  hintText: '例: 著書',
                ),
                onChanged: (value) => setState(() => _inverseName = value),
              ),
              const SizedBox(height: 12),
              _MultiplicityTile(
                title: '${widget.sourceType.name} → 関連先',
                value: _sourceMultiple,
                onChanged: (value) => setState(() => _sourceMultiple = value),
              ),
              _MultiplicityTile(
                title: '関連先 → ${widget.sourceType.name}',
                value: _inverseMultiple,
                onChanged: (value) => setState(() => _inverseMultiple = value),
              ),
              const SizedBox(height: 8),
              Text(
                '保存すると両方のObject TypeにRelationプロパティが作成され、どちら側から編集しても逆側へ同期されます。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          onPressed: _canSave
              ? () => Navigator.pop(
                    context,
                    BidirectionalRelationDraft(
                      sourceName: _sourceName.trim(),
                      targetObjectTypeId: _targetObjectTypeId!,
                      inverseName: _inverseName.trim(),
                      sourceMultiple: _sourceMultiple,
                      inverseMultiple: _inverseMultiple,
                    ),
                  )
              : null,
          child: const Text('追加'),
        ),
      ],
    );
  }
}

class _MultiplicityTile extends StatelessWidget {
  const _MultiplicityTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: Text(value ? '複数のObjectを関連付け可能' : '1つのObjectだけ関連付け'),
      value: value,
      onChanged: onChanged,
    );
  }
}
