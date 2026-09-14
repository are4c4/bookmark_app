import 'package:bookmark_app/widgets/app_empty_state.dart';
import 'package:bookmark_app/widgets/detail_section.dart';
import 'package:flutter/material.dart';

/// Deterministic development/test catalog for established shared UI primitives.
///
/// This is intentionally test-only: it provides stable representative states
/// for widget regressions and later advisory UI-audit reuse without becoming a
/// second application navigation surface.
class SharedComponentCatalog extends StatelessWidget {
  const SharedComponentCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Shared component catalog'),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No items yet',
                message: 'Create an item to populate this shared empty state.',
                actionLabel: 'Create item',
                onAction: _noop,
              ),
            ),
            const SizedBox(height: 16),
            const DetailSection(
              title: 'Details',
              icon: Icons.info_outline,
              trailing: Tooltip(
                message: 'More detail actions',
                child: Icon(Icons.more_horiz),
              ),
              child: Text('Shared detail-section content'),
            ),
          ],
        ),
      ),
    );
  }

  static void _noop() {}
}
