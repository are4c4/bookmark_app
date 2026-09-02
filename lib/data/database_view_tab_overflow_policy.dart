import 'database_view_store.dart';

class DatabaseViewTabPartition {
  const DatabaseViewTabPartition({
    required this.visible,
    required this.overflow,
  });

  final List<DatabaseViewConfig> visible;
  final List<DatabaseViewConfig> overflow;

  bool get hasOverflow => overflow.isNotEmpty;
}

/// Keeps top View tabs compact while guaranteeing that the active View remains
/// directly visible. Hidden Views stay in their persisted order and can be
/// exposed by an overflow menu without changing View identity or configuration.
class DatabaseViewTabOverflowPolicy {
  const DatabaseViewTabOverflowPolicy({this.maxVisibleTabs = 6})
      : assert(maxVisibleTabs > 0);

  final int maxVisibleTabs;

  DatabaseViewTabPartition partition({
    required List<DatabaseViewConfig> views,
    required int? activeViewId,
  }) {
    final snapshot = List<DatabaseViewConfig>.unmodifiable(views);
    if (snapshot.length <= maxVisibleTabs) {
      return DatabaseViewTabPartition(
        visible: snapshot,
        overflow: const <DatabaseViewConfig>[],
      );
    }

    DatabaseViewConfig? active;
    if (activeViewId != null) {
      for (final view in snapshot) {
        if (view.id == activeViewId) {
          active = view;
          break;
        }
      }
    }

    final visible = snapshot.take(maxVisibleTabs).toList(growable: true);
    if (active != null && !visible.any((view) => view.id == active!.id)) {
      visible[visible.length - 1] = active;
    }
    final visibleIds = visible.map((view) => view.id).toSet();
    final overflow = snapshot
        .where((view) => !visibleIds.contains(view.id))
        .toList(growable: false);

    return DatabaseViewTabPartition(
      visible: List<DatabaseViewConfig>.unmodifiable(visible),
      overflow: List<DatabaseViewConfig>.unmodifiable(overflow),
    );
  }
}
