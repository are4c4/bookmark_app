import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/database_property_authoring_service.dart';
import '../../../../domain/object_model.dart';
import 'property_add_popover.dart';

typedef DatabasePropertyCreated = FutureOr<void> Function(int propertyId);

/// Production-ready compact Property-add host for generic Database surfaces.
///
/// This widget keeps the existing compact reveal/create interaction while
/// loading Relation target ObjectTypes from the canonical authoring service.
/// Relation persistence always goes through [DatabasePropertyAuthoringService]
/// and therefore through `ObjectStore.createRelationProperty`; no Relation
/// config is serialized by presentation code.
class DatabasePropertyAddPopoverHost extends StatefulWidget {
  const DatabasePropertyAddPopoverHost({
    super.key,
    required this.workspaceId,
    required this.objectTypeId,
    required this.authoring,
    required this.hiddenProperties,
    required this.onRevealExisting,
    required this.onCreated,
    this.buttonKey = const ValueKey('database-property-add-button'),
    this.buttonLabel,
  });

  final int workspaceId;
  final int objectTypeId;
  final DatabasePropertyAuthoringService authoring;
  final List<PropertyAddCandidate> hiddenProperties;
  final RevealExistingProperty onRevealExisting;
  final DatabasePropertyCreated onCreated;
  final Key? buttonKey;
  final String? buttonLabel;

  @override
  State<DatabasePropertyAddPopoverHost> createState() =>
      _DatabasePropertyAddPopoverHostState();
}

class _DatabasePropertyAddPopoverHostState
    extends State<DatabasePropertyAddPopoverHost> {
  late Future<List<AppObjectType>> _targetsFuture;

  static const _types = <PropertyAddTypeOption>[
    PropertyAddTypeOption(
      key: 'text',
      label: 'テキスト',
      icon: Icons.text_fields,
    ),
    PropertyAddTypeOption(
      key: 'number',
      label: '数値',
      icon: Icons.numbers,
    ),
    PropertyAddTypeOption(
      key: 'checkbox',
      label: 'チェックボックス',
      icon: Icons.check_box_outlined,
    ),
    PropertyAddTypeOption(
      key: 'date',
      label: '日付',
      icon: Icons.calendar_today_outlined,
    ),
    PropertyAddTypeOption(
      key: 'url',
      label: 'URL',
      icon: Icons.link,
    ),
    PropertyAddTypeOption(
      key: 'rating',
      label: '評価',
      icon: Icons.star_outline,
    ),
    PropertyAddTypeOption(
      key: 'relation',
      label: 'リレーション',
      icon: Icons.swap_horiz,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _reloadTargets();
  }

  @override
  void didUpdateWidget(covariant DatabasePropertyAddPopoverHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.authoring != widget.authoring) {
      _reloadTargets();
    }
  }

  void _reloadTargets() {
    _targetsFuture = widget.authoring.relationTargets(
      workspaceId: widget.workspaceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppObjectType>>(
      future: _targetsFuture,
      builder: (context, snapshot) {
        final targets = snapshot.data ?? const <AppObjectType>[];
        return PropertyAddPopover(
          buttonKey: widget.buttonKey,
          buttonLabel: widget.buttonLabel,
          hiddenProperties: widget.hiddenProperties,
          propertyTypes: _types,
          relationTargets: targets
              .map(
                (type) => PropertyAddRelationTarget(
                  id: type.id,
                  name: type.name,
                  icon: type.icon,
                  isBuiltIn: type.kind == ObjectTypeKind.system,
                ),
              )
              .toList(growable: false),
          onRevealExisting: widget.onRevealExisting,
          onCreateNew: _create,
        );
      },
    );
  }

  Future<void> _create(PropertyCreateRequest request) async {
    try {
      final propertyId = await widget.authoring.createProperty(
        objectTypeId: widget.objectTypeId,
        name: request.name,
        type: ObjectPropertyDefinition.fromStorageType(request.type),
        relationTargetObjectTypeId: request.relationTargetObjectTypeId,
        relationMultiple: request.relationMultiple,
      );
      await widget.onCreated(propertyId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('プロパティを追加できませんでした: $error')),
      );
    }
  }
}
