import 'package:flutter/material.dart';

import '../domain/object_query.dart';

class ObjectHierarchyMatchModeField extends StatelessWidget {
  const ObjectHierarchyMatchModeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ObjectHierarchyMatchMode value;
  final ValueChanged<ObjectHierarchyMatchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ObjectHierarchyMatchMode>(
      initialValue: value,
      decoration: const InputDecoration(labelText: '階層'),
      items: ObjectHierarchyMatchMode.values
          .map(
            (mode) => DropdownMenuItem<ObjectHierarchyMatchMode>(
              value: mode,
              child: Text(labelFor(mode)),
            ),
          )
          .toList(growable: false),
      onChanged: (mode) {
        if (mode != null) onChanged(mode);
      },
    );
  }

  static String labelFor(ObjectHierarchyMatchMode mode) => switch (mode) {
    ObjectHierarchyMatchMode.exact => '完全一致',
    ObjectHierarchyMatchMode.isOrBelow => '配下を含む',
    ObjectHierarchyMatchMode.belowOnly => '配下のみ',
    ObjectHierarchyMatchMode.excludeBranch => '枝を除外',
  };
}
