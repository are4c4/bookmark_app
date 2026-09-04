import 'package:flutter/material.dart';

import '../../../../domain/object_detail_property_presentation.dart';
import '../../../../domain/object_model.dart';

enum ObjectPropertyValueDensity { compact, normal }

/// Shared semantic renderer for Object Property values across Database views
/// and Object detail hosts.
///
/// Relation labels must be resolved by the caller through canonical Relation
/// read/query data. Persisted Relation ids are intentionally never rendered.
class ObjectPropertyValueView extends StatelessWidget {
  const ObjectPropertyValueView({
    super.key,
    required this.presentation,
    this.relationLabels = const <String>[],
    this.density = ObjectPropertyValueDensity.normal,
    this.maxItems,
  });

  final ObjectDetailPropertyPresentation presentation;
  final List<String> relationLabels;
  final ObjectPropertyValueDensity density;
  final int? maxItems;

  bool get _compact => density == ObjectPropertyValueDensity.compact;

  @override
  Widget build(BuildContext context) {
    if (presentation.isHidden) return const SizedBox.shrink();
    final property = presentation.property;
    final value = presentation.value;

    if (property.isRelation) {
      return _chips(context, relationLabels);
    }

    return switch (property.type) {
      ObjectPropertyType.select => _chips(
          context,
          value == null || '$value'.isEmpty ? const <String>[] : <String>['$value'],
        ),
      ObjectPropertyType.multiSelect => _chips(
          context,
          value is Iterable
              ? value.map((item) => '$item').where((item) => item.isNotEmpty).toList()
              : value == null || '$value'.isEmpty
                  ? const <String>[]
                  : <String>['$value'],
        ),
      ObjectPropertyType.checkbox => Icon(
          value == true ? Icons.check_box : Icons.check_box_outline_blank,
          size: _compact ? 17 : 19,
        ),
      ObjectPropertyType.rating => _rating(value),
      ObjectPropertyType.url => _text(
          context,
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: value == null || '$value'.isEmpty
                ? null
                : TextDecoration.underline,
          ),
        ),
      ObjectPropertyType.image => _assetChip(context, value, Icons.image_outlined),
      ObjectPropertyType.file => _assetChip(context, value, Icons.attach_file),
      _ => _text(context, presentation.displayText),
    };
  }

  Widget _chips(BuildContext context, List<String> labels) {
    final normalized = labels.where((label) => label.trim().isNotEmpty).toList();
    if (normalized.isEmpty) return _empty(context);
    final limit = maxItems == null ? normalized.length : maxItems!.clamp(0, normalized.length);
    final visible = normalized.take(limit).toList(growable: false);
    final overflow = normalized.length - visible.length;
    return Wrap(
      spacing: _compact ? 3 : 5,
      runSpacing: _compact ? 2 : 4,
      children: [
        ...visible.map(
          (label) => Chip(
            visualDensity: _compact ? VisualDensity.compact : VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: EdgeInsets.symmetric(horizontal: _compact ? 2 : 4),
            label: Text(
              label,
              style: TextStyle(fontSize: _compact ? 11 : 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (overflow > 0)
          Chip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text('+$overflow', style: const TextStyle(fontSize: 11)),
          ),
      ],
    );
  }

  Widget _rating(dynamic value) {
    final count = (value is num ? value.toInt() : int.tryParse('$value') ?? 0).clamp(0, 5);
    if (count == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (_) => Icon(Icons.star, size: _compact ? 14 : 16),
      ),
    );
  }

  Widget _assetChip(BuildContext context, dynamic value, IconData icon) {
    if (value == null || '$value'.isEmpty) return _empty(context);
    return Chip(
      visualDensity: _compact ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(icon, size: _compact ? 14 : 16),
      label: Text('$value', overflow: TextOverflow.ellipsis),
    );
  }

  Widget _text(BuildContext context, dynamic value, {TextStyle? style}) {
    if (value == null || '$value'.isEmpty || '$value' == 'なし') return _empty(context);
    return Text(
      '$value',
      maxLines: _compact ? 1 : null,
      overflow: _compact ? TextOverflow.ellipsis : null,
      style: style,
    );
  }

  Widget _empty(BuildContext context) => Text(
        'なし',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}
