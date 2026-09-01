import 'package:flutter/material.dart';

import '../data/person_roles.dart';
import '../views/bookmark_property_order.dart';
import '../views/bookmark_query_engine.dart';

class BookmarkPropertyOrderResult {
  const BookmarkPropertyOrderResult({
    required this.order,
    required this.visibleProperties,
    required this.visibleRoles,
  });

  final List<String> order;
  final Set<BookmarkStage1Property> visibleProperties;
  final Set<String> visibleRoles;
}

Future<BookmarkPropertyOrderResult?> showBookmarkPropertyOrderDialog({
  required BuildContext context,
  required List<String> currentOrder,
  required Set<BookmarkStage1Property> visibleProperties,
  required Set<String> visibleRoles,
}) {
  var order = normalizeBookmarkPropertyOrder(currentOrder);
  final selectedProperties = {...visibleProperties};
  final selectedRoles = {...visibleRoles};

  bool isVisible(String key) {
    if (key.startsWith('role:')) return selectedRoles.contains(key.substring(5));
    final property = bookmarkPropertyFromKey(key);
    return property != null && selectedProperties.contains(property);
  }

  String labelFor(String key) {
    if (key.startsWith('role:')) return key.substring(5);
    final property = bookmarkPropertyFromKey(key);
    return property == null ? key : bookmarkPropertyLabel(property);
  }

  void toggle(String key, StateSetter setLocalState) {
    setLocalState(() {
      if (key.startsWith('role:')) {
        final role = key.substring(5);
        if (!selectedRoles.remove(role)) selectedRoles.add(role);
      } else {
        final property = bookmarkPropertyFromKey(key);
        if (property != null && !selectedProperties.remove(property)) {
          selectedProperties.add(property);
        }
      }
    });
  }

  return showDialog<BookmarkPropertyOrderResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) => AlertDialog(
        title: const Text('プロパティ'),
        content: SizedBox(
          width: 430,
          height: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ドラッグして表示順を変更できます',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: order.length,
                  onReorder: (oldIndex, newIndex) => setLocalState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = order.removeAt(oldIndex);
                    order.insert(newIndex, item);
                  }),
                  itemBuilder: (context, index) {
                    final key = order[index];
                    final visible = isVisible(key);
                    final isRole = key.startsWith('role:');
                    return Material(
                      key: ValueKey('property-order:$key'),
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => toggle(key, setLocalState),
                        child: SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const SizedBox(
                                  width: 34,
                                  height: 44,
                                  child: Icon(Icons.drag_indicator, size: 19),
                                ),
                              ),
                              Icon(
                                isRole ? Icons.person_outline : Icons.tune,
                                size: 17,
                              ),
                              const SizedBox(width: 9),
                              Expanded(child: Text(labelFor(key))),
                              Icon(
                                visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 18,
                                color: visible
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Text(
                '人物プロパティ: ${defaultPersonRoles.length}種類',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              BookmarkPropertyOrderResult(
                order: [...order],
                visibleProperties: {...selectedProperties},
                visibleRoles: {...selectedRoles},
              ),
            ),
            child: const Text('適用'),
          ),
        ],
      ),
    ),
  );
}
