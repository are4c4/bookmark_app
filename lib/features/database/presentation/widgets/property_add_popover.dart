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

class PropertyCreateRequest {
  const PropertyCreateRequest({
    required this.name,
    required this.type,
  });

  final String name;
  final String type;
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
/// Property type options.
class PropertyAddPopover extends StatefulWidget {
  const PropertyAddPopover({
    super.key,
    required this.hiddenProperties,
    required this.propertyTypes,
    required this.onRevealExisting,
    required this.onCreateNew,
    this.tooltip = 'プロパティを追加',
  });

  final List<PropertyAddCandidate> hiddenProperties;
  final List<PropertyAddTypeOption> propertyTypes;
  final RevealExistingProperty onRevealExisting;
  final CreatePropertyFromPopover onCreateNew;
  final String tooltip;

  @override
  State<PropertyAddPopover> createState() => _PropertyAddPopoverState();
}

class _PropertyAddPopoverState extends State<PropertyAddPopover> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  bool _creating = false;
  String _selectedType = '';

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _reset() {
    _searchController.clear();
    _nameController.clear();
    _creating = false;
    _selectedType = widget.propertyTypes.firstOrNull?.key ?? '';
  }

  List<PropertyAddCandidate> get _filteredProperties {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.hiddenProperties;
    return widget.hiddenProperties
        .where((property) => property.name.toLowerCase().contains(query))
        .toList(growable: false);
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
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedType.isEmpty) return;
    await widget.onCreateNew(
      PropertyCreateRequest(name: name, type: _selectedType),
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
          width: 320,
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
      builder: (context, controller, child) => IconButton(
        key: const ValueKey('property-add-popover-button'),
        tooltip: widget.tooltip,
        icon: const Icon(Icons.add, size: 18),
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
      ),
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
                  onSelected: (_) => setState(() => _selectedType = option.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('property-add-create-submit'),
          onPressed: _nameController.text.trim().isEmpty || _selectedType.isEmpty
              ? null
              : () => _create(controller),
          child: const Text('追加'),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
