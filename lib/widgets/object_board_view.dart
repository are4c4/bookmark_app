import 'package:flutter/material.dart';

import '../domain/object_group.dart';
import '../domain/object_model.dart';

class ObjectBoardDragData {
  const ObjectBoardDragData({
    required this.object,
    required this.sourceGroup,
  });

  final AppObject object;
  final ObjectGroupBucket<AppObject> sourceGroup;
}

typedef ObjectBoardMoveCallback = Future<void> Function(
  AppObject object,
  ObjectGroupBucket<AppObject> sourceGroup,
  ObjectGroupBucket<AppObject> targetGroup,
);

typedef ObjectBoardCreateCallback = Future<void> Function(
  ObjectGroupBucket<AppObject> group,
);

class ObjectBoardView extends StatelessWidget {
  const ObjectBoardView({
    super.key,
    required this.groups,
    required this.onObjectTap,
    this.onMoveObject,
    this.onCreateInGroup,
    this.cardSubtitleBuilder,
    this.columnWidth = 286,
  });

  final List<ObjectGroupBucket<AppObject>> groups;
  final ValueChanged<AppObject> onObjectTap;
  final ObjectBoardMoveCallback? onMoveObject;
  final ObjectBoardCreateCallback? onCreateInGroup;
  final String? Function(AppObject object)? cardSubtitleBuilder;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(child: Text('表示するグループがありません'));
    }

    return Scrollbar(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: columnWidth,
          child: _BoardColumn(
            group: groups[index],
            onObjectTap: onObjectTap,
            onMoveObject: onMoveObject,
            onCreateInGroup: onCreateInGroup,
            cardSubtitleBuilder: cardSubtitleBuilder,
          ),
        ),
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.group,
    required this.onObjectTap,
    required this.onMoveObject,
    required this.onCreateInGroup,
    required this.cardSubtitleBuilder,
  });

  final ObjectGroupBucket<AppObject> group;
  final ValueChanged<AppObject> onObjectTap;
  final ObjectBoardMoveCallback? onMoveObject;
  final ObjectBoardCreateCallback? onCreateInGroup;
  final String? Function(AppObject object)? cardSubtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final column = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: group.items.isEmpty
                ? Center(
                    child: Text(
                      'Objectはありません',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                    itemCount: group.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final object = group.items[index];
                      return _draggableCard(context, object);
                    },
                  ),
          ),
          if (onCreateInGroup != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: TextButton.icon(
                onPressed: () => onCreateInGroup!(group),
                icon: const Icon(Icons.add, size: 16),
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('新規Object'),
                ),
              ),
            ),
        ],
      ),
    );

    if (onMoveObject == null) return column;
    return DragTarget<ObjectBoardDragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.sourceGroup.key != group.key &&
          !group.items.any((item) => item.id == details.data.object.id),
      onAcceptWithDetails: (details) {
        onMoveObject!(
          details.data.object,
          details.data.sourceGroup,
          group,
        );
      },
      builder: (context, candidates, rejected) {
        if (candidates.isEmpty) return column;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.primary, width: 2),
          ),
          child: column,
        );
      },
    );
  }

  Widget _draggableCard(BuildContext context, AppObject object) {
    final card = _ObjectBoardCard(
      object: object,
      subtitle: cardSubtitleBuilder?.call(object),
      onTap: () => onObjectTap(object),
    );
    if (onMoveObject == null) return card;
    return LongPressDraggable<ObjectBoardDragData>(
      data: ObjectBoardDragData(object: object, sourceGroup: group),
      feedback: SizedBox(
        width: 260,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(7),
          child: _ObjectBoardCard(
            object: object,
            subtitle: cardSubtitleBuilder?.call(object),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: .35, child: card),
      child: card,
    );
  }
}

class _ObjectBoardCard extends StatelessWidget {
  const _ObjectBoardCard({
    required this.object,
    this.subtitle,
    this.onTap,
  });

  final AppObject object;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                object.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
