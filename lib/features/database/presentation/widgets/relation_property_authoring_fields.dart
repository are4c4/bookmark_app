import 'package:flutter/material.dart';

/// Presentation model for one Relation target ObjectType.
///
/// [isBuiltIn] is intentionally presentation-only. Persistence and validation
/// remain owned by the canonical Object/Relation schema services.
class RelationPropertyTargetOption {
  const RelationPropertyTargetOption({
    required this.objectTypeId,
    required this.name,
    required this.icon,
    required this.isBuiltIn,
  });

  final int objectTypeId;
  final String name;
  final String icon;
  final bool isBuiltIn;

  String get kindLabel => isBuiltIn ? '組み込み ObjectType' : 'カスタム ObjectType';
}

/// Compact Relation-specific schema-authoring fields.
///
/// This widget owns only target discovery/presentation and explicit cardinality
/// choice. It performs no schema mutation. The host must pass the selected target
/// and cardinality to the canonical Relation Property creation/update boundary.
class RelationPropertyAuthoringFields extends StatefulWidget {
  const RelationPropertyAuthoringFields({
    super.key,
    required this.targets,
    required this.selectedTargetObjectTypeId,
    required this.multiple,
    required this.onTargetChanged,
    required this.onMultipleChanged,
    this.keyPrefix = 'relation-property',
    this.showResultsInitially = false,
  });

  final List<RelationPropertyTargetOption> targets;
  final int? selectedTargetObjectTypeId;
  final bool multiple;
  final ValueChanged<int?> onTargetChanged;
  final ValueChanged<bool> onMultipleChanged;
  final String keyPrefix;
  final bool showResultsInitially;

  @override
  State<RelationPropertyAuthoringFields> createState() =>
      _RelationPropertyAuthoringFieldsState();
}

class _RelationPropertyAuthoringFieldsState
    extends State<RelationPropertyAuthoringFields> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late bool _showResults;

  @override
  void initState() {
    super.initState();
    _showResults = widget.showResultsInitially;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  RelationPropertyTargetOption? get _selectedTarget {
    final selectedId = widget.selectedTargetObjectTypeId;
    if (selectedId == null) return null;
    for (final target in widget.targets) {
      if (target.objectTypeId == selectedId) return target;
    }
    return null;
  }

  List<RelationPropertyTargetOption> get _filteredTargets {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.targets;
    return widget.targets.where((target) {
      final haystack = '${target.name} ${target.kindLabel}'.toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  void _select(RelationPropertyTargetOption target) {
    widget.onTargetChanged(target.objectTypeId);
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() => _showResults = false);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedTarget;
    final filtered = _filteredTargets;
    final scheme = Theme.of(context).colorScheme;
    final keyPrefix = widget.keyPrefix;
    final resultsHeight = filtered.isEmpty
        ? 48.0
        : (filtered.length * 64.0).clamp(64.0, 220.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('$keyPrefix-target-search'),
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            labelText: '関連先 ObjectType',
            hintText: selected == null
                ? '名前で検索'
                : '${selected.icon} ${selected.name} · ${selected.kindLabel}',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: selected == null
                ? null
                : IconButton(
                    key: ValueKey('$keyPrefix-target-clear'),
                    tooltip: '関連先をクリア',
                    onPressed: () {
                      widget.onTargetChanged(null);
                      _searchController.clear();
                      setState(() => _showResults = true);
                      _searchFocus.requestFocus();
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
          onTap: () => setState(() => _showResults = true),
          onChanged: (_) => setState(() => _showResults = true),
        ),
        if (_showResults) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: resultsHeight,
            child: Container(
              key: ValueKey('$keyPrefix-target-results'),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(6),
              ),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('一致するObjectTypeがありません'),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final target = filtered[index];
                        final isSelected = target.objectTypeId ==
                            widget.selectedTargetObjectTypeId;
                        return ListTile(
                          key: ValueKey(
                            '$keyPrefix-target-${target.objectTypeId}',
                          ),
                          dense: true,
                          leading: Text(
                            target.icon,
                            style: const TextStyle(fontSize: 18),
                          ),
                          title: Text(target.name),
                          subtitle: Text(target.kindLabel),
                          trailing: isSelected
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onTap: () => _select(target),
                        );
                      },
                    ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Cardinality',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          key: ValueKey('$keyPrefix-cardinality'),
          segments: const [
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.looks_one_outlined, size: 17),
              label: Text('single'),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.library_add_outlined, size: 17),
              label: Text('multi'),
            ),
          ],
          selected: {widget.multiple},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              widget.onMultipleChanged(selection.first);
            }
          },
        ),
        const SizedBox(height: 4),
        Text(
          widget.multiple
              ? '複数のObjectを関連付けできます'
              : '1つのObjectだけ関連付けます',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
