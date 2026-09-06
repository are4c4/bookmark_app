import 'dart:async';

import 'package:flutter/material.dart';

class PropertyAddCandidate {
  const PropertyAddCandidate({
    required this.id,
    required this.name,
    required this.type,
  });

  final int id;
  final String name;
  final String type;
}

class PropertyAddTypeOption {
  const PropertyAddTypeOption({
    required this.key,
    required this.label,
    this.icon,
  });

  final String key;
  final String label;
  final IconData? icon;
}

class PropertyAddRelationTarget {
  const PropertyAddRelationTarget({
    required this.id,
    required this.name,
    required this.isBuiltIn,
    this.icon = '',
  });

  final int id;
  final String name;
  final bool isBuiltIn;
  final String icon;
}

class PropertyCreateRequest {
  const PropertyCreateRequest({
    required this.name,
    required this.type,
    this.relationTargetObjectTypeId,
    this.relationMultiple = true,
  });

  final String name;
  final String type;
  final int? relationTargetObjectTypeId;
  final bool relationMultiple;
}

typedef RevealExistingProperty = FutureOr<void> Function(
  PropertyAddCandidate property,
);
typedef CreatePropertyFromPopover = FutureOr<void> Function(
  PropertyCreateRequest request,
);

/// Compact, anchored Property-add surface shared by Database/Object hosts.
///
/// Persistence and Property-type semantics remain caller-owned. This widget only
/// owns the common interaction: search hidden Properties, reveal one directly,
/// or switch into a compact create-new flow using caller-supplied canonical
/// Property type options. When callers expose `relation`, the same flow also
/// collects an explicit target ObjectType and single/multi cardinality; callers
/// remain responsible for passing that request through canonical Relation schema
/// validation rather than writing Relation config directly from presentation.
class PropertyAddPopover extends StatefulWidget {
  const PropertyAddPopover({
    super.key,
    required this.hiddenProperties,
    required this.propertyTypes,
    required this.onRevealExisting,
    required this.onCreateNew,
    this.relationTargets = const <PropertyAddRelationTarget>[],
    this.tooltip = 'プロパティを追加',
    this.buttonKey = const ValueKey('property-add-popover-button'),
    this.buttonLabel,
  });

  final List<PropertyAddCandidate> hiddenProperties;
  final List<PropertyAddTypeOption> propertyTypes;
  final List<PropertyAddRelationTarget> relationTargets;
  final RevealExistingProperty onRevealExisting;
  final CreatePropertyFromPopover onCreateNew;
  final String tooltip;
  final Key? buttonKey;
  final String? buttonLabel;

  @override
  State<PropertyAddPopover> createState() => _PropertyAddPopoverState();
}

class _PropertyAddPopoverState extends State<PropertyAddPopover> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _relationTargetSearchController = TextEditingController();
  bool _creating = false;
  String _selectedType = '';
  int? _selectedRelationTargetId;
  bool _relationMultiple = true;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.propertyTypes.firstOrNull?.key ?? '';
  }

  @override
  void didUpdateWidget(covariant PropertyAddPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.propertyTypes.every((option) => option.key != _selectedType)) {
      _selectedType = widget.propertyTypes.firstOrNull?.key ?? '';
    }
    if (_selectedRelationTargetId != null &&
        widget.relationTargets.every(
          (target) => target.id != _selectedRelationTargetId,
        )) {
      _selectedRelationTargetId = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _relationTargetSearchController.dispose();
    super.dispose();
  }

  void _reset() {
    _searchController.clear();
    _nameController.clear();
    _relationTargetSearchController.clear();
    _creating = false;
    _selectedType = widget.propertyTypes.firstOrNull?.key ?? '';
    _selectedRelationTargetId = null;
    _relationMultiple = true;
  }

  List<PropertyAddCandidate> get _filteredProperties {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.hiddenProperties;
    return widget.hiddenProperties
        .where((property) => property.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  List<PropertyAddRelationTarget> get _filteredRelationTargets {
    final query = _relationTargetSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.relationTargets;
    return widget.relationTargets
        .where((target) => target.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  bool get _canCreate {
    if (_nameController.text.trim().isEmpty || _selectedType.isEmpty) {
      return false;
    }
    if (_selectedType == 'relation') {
      return _selectedRelationTargetId != null;
    }
    return true;
  }

  Future<void> _reveal(
    MenuController controller,
    PropertyAddCandidate property,
  ) async {
    await widget.onRevealExisting(property);
    if (!mounted) return;
    controller.close();
    setState(_reset);
  }

  Future<void> _create(MenuController controller) async {
    if (!_canCreate) return;
    final isRelation = _selectedType == 'relation';
    await widget.onCreateNew(
      PropertyCreateRequest(
        name: _nameController.text.trim(),
        type: _selectedType,
        relationTargetObjectTypeId:
            isRelation ? _selectedRelationTargetId : null,
        relationMultiple: isRelation ? _relationMultiple : true,
      ),
    );
    if (!mounted) return;
    controller.close();
    setState(_reset);
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      onClose: () {
        if (mounted) setState(_reset);
      },
      menuChildren: [
        SizedBox(
          width: 340,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Builder(
              builder: (menuContext) {
                final controller = MenuController.maybeOf(menuContext)!;
                return _creating
                    ? _buildCreatePanel(controller)
                    : _buildSearchPanel(controller);
              },
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        void toggle() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        final label = widget.buttonLabel;
        if (label != null) {
          return Tooltip(
            message: widget.tooltip,
            child: TextButton.icon(
              key: widget.buttonKey,
              onPressed: toggle,
              icon: const Icon(Icons.add, size: 16),
              label: Text(label),
            ),
          );
        }
        return IconButton(
          key: widget.buttonKey,
          tooltip: widget.tooltip,
          icon: const Icon(Icons.add, size: 18),
          onPressed: toggle,
        );
      },
    );
  }

  Widget _buildSearchPanel(MenuController controller) {
    final filtered = _filteredProperties;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('property-add-search'),
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'プロパティを検索',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (filtered.isNotEmpty) ...[
          Text(
            '非表示のプロパティ',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 210),
            child: SingleChildScrollView(
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: filtered
                    .map(
                      (property) => ListTile(
                        key: ValueKey('property-add-existing-${property.id}'),
                        dense: true,
                        minTileHeight: 38,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.view_column_outlined, size: 18),
                        title: Text(property.name),
                        subtitle: Text(property.type),
                        onTap: () => _reveal(controller, property),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 14),
        ],
        TextButton.icon(
          key: const ValueKey('property-add-create-new'),
          onPressed: () => setState(() {
            _creating = true;
            _nameController.text = _searchController.text.trim();
          }),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Align(
            alignment: Alignment.centerLeft,
            child: Text('新しいプロパティ'),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatePanel(MenuController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('property-add-create-back'),
              tooltip: '戻る',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _creating = false),
              icon: const Icon(Icons.arrow_back, size: 18),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                '新しいプロパティ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('property-add-create-name'),
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            isDense: true,
            labelText: '名前',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _create(controller),
        ),
        const SizedBox(height: 10),
        Text('種類', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.propertyTypes
              .map(
                (option) => ChoiceChip(
                  key: ValueKey('property-add-type-${option.key}'),
                  avatar: option.icon == null ? null : Icon(option.icon, size: 16),
                  label: Text(option.label),
                  selected: _selectedType == option.key,
                  onSelected: (_) => setState(() {
                    _selectedType = option.key;
                    if (_selectedType != 'relation') {
                      _selectedRelationTargetId = null;
                      _relationTargetSearchController.clear();
                      _relationMultiple = true;
                    }
                  }),
                ),
              )
              .toList(),
        ),
        if (_selectedType == 'relation') ...[
          const SizedBox(height: 12),
          _buildRelationFields(),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('property-add-create-submit'),
          onPressed: _canCreate ? () => _create(controller) : null,
          child: const Text('追加'),
        ),
      ],
    );
  }

  Widget _buildRelationFields() {
    final filteredTargets = _filteredRelationTargets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('関連先 ObjectType', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('property-add-relation-target-search'),
          controller: _relationTargetSearchController,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'ObjectTypeを検索',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: filteredTargets.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('一致するObjectTypeがありません'),
                )
              : SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: filteredTargets
                        .map(
                          (target) => ListTile(
                            key: ValueKey(
                              'property-add-relation-target-${target.id}',
                            ),
                            dense: true,
                            minTileHeight: 42,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            leading: target.icon.trim().isEmpty
                                ? const Icon(Icons.category_outlined, size: 18)
                                : Text(target.icon),
                            title: Text(target.name),
                            subtitle: Text(
                              target.isBuiltIn
                                  ? '組み込み ObjectType'
                                  : 'カスタム ObjectType',
                            ),
                            trailing: _selectedRelationTargetId == target.id
                                ? const Icon(Icons.check, size: 18)
                                : null,
                            onTap: () => setState(
                              () => _selectedRelationTargetId = target.id,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Text('関連できる数', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          key: const ValueKey('property-add-relation-cardinality'),
          segments: const [
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.looks_one_outlined, size: 16),
              label: Text('single'),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.library_add_outlined, size: 16),
              label: Text('multi'),
            ),
          ],
          selected: <bool>{_relationMultiple},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              setState(() => _relationMultiple = selection.single),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
