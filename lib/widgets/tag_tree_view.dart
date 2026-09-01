import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../ui/ui_tokens.dart';
import '../views/tag_tree_model.dart';

class TagTreeView extends StatefulWidget {
  const TagTreeView({
    super.key,
    required this.model,
    required this.query,
    required this.selectedTagId,
    required this.focusedKey,
    required this.multiSelectedIds,
    required this.onSelectTag,
    required this.onFocusRow,
    required this.onToggleGroup,
    required this.onToggleTag,
    required this.onToggleMultiSelect,
    required this.onBeginRename,
    required this.onSubmitRename,
    required this.onCancelRename,
    required this.onMenuAction,
    required this.onDrop,
    required this.canDrop,
    required this.onShowDirect,
    required this.onShowAggregate,
    required this.onDragStarted,
    required this.onDragEnded,
    this.editingTagId,
    this.editController,
    this.editError,
  });

  final TagTreeModel model;
  final String query;
  final int? selectedTagId;
  final String? focusedKey;
  final Set<int> multiSelectedIds;
  final int? editingTagId;
  final TextEditingController? editController;
  final String? editError;
  final ValueChanged<Tag> onSelectTag;
  final ValueChanged<String> onFocusRow;
  final ValueChanged<int?> onToggleGroup;
  final ValueChanged<Tag> onToggleTag;
  final ValueChanged<Tag> onToggleMultiSelect;
  final ValueChanged<Tag> onBeginRename;
  final ValueChanged<Tag> onSubmitRename;
  final VoidCallback onCancelRename;
  final void Function(Tag tag, String action) onMenuAction;
  final void Function(Tag dragged, TagTreeRow target) onDrop;
  final bool Function(Tag dragged, TagTreeRow target) canDrop;
  final ValueChanged<Tag> onShowDirect;
  final ValueChanged<Tag> onShowAggregate;
  final ValueChanged<Tag> onDragStarted;
  final VoidCallback onDragEnded;

  @override
  State<TagTreeView> createState() => _TagTreeViewState();
}

class _TagTreeViewState extends State<TagTreeView> {
  Timer? _expandTimer;
  String? _dropTargetKey;
  bool _dropAllowed = false;

  @override
  void dispose() {
    _expandTimer?.cancel();
    super.dispose();
  }

  void _enterDrop(Tag dragged, TagTreeRow row) {
    final allowed = widget.canDrop(dragged, row);
    final changed = _dropTargetKey != row.focusKey;
    if (changed) {
      _expandTimer?.cancel();
      setState(() {
        _dropTargetKey = row.focusKey;
        _dropAllowed = allowed;
      });
    } else if (_dropAllowed != allowed) {
      setState(() => _dropAllowed = allowed);
    }
    if (!changed || !allowed || row.expanded || !row.hasChildren) return;
    _expandTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _dropTargetKey != row.focusKey) return;
      if (row.kind == TagTreeRowKind.group) {
        widget.onToggleGroup(row.groupId);
      } else {
        widget.onToggleTag(row.tag!);
      }
    });
  }

  void _leaveDrop() {
    _expandTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _dropTargetKey = null;
      _dropAllowed = false;
    });
  }

  TextSpan _highlight(String text, TextStyle style) {
    final query = widget.query.trim();
    if (query.isEmpty) return TextSpan(text: text, style: style);
    final lower = text.toLowerCase();
    final match = lower.indexOf(query.toLowerCase());
    if (match < 0) return TextSpan(text: text, style: style);
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, match)),
        TextSpan(
          text: text.substring(match, match + query.length),
          style: style.copyWith(
            fontWeight: FontWeight.w700,
            backgroundColor:
                Theme.of(context).colorScheme.tertiaryContainer,
          ),
        ),
        TextSpan(text: text.substring(match + query.length)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.model.rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(UiTokens.space24),
          child: Text('条件に一致するタグはありません'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: UiTokens.space24),
      itemCount: widget.model.rows.length,
      itemExtent: 38,
      itemBuilder: (context, index) {
        final row = widget.model.rows[index];
        return row.kind == TagTreeRowKind.group
            ? _groupRow(row)
            : _tagRow(row);
      },
    );
  }

  Widget _groupRow(TagTreeRow row) => DragTarget<Tag>(
        onWillAcceptWithDetails: (details) {
          _enterDrop(details.data, row);
          return widget.canDrop(details.data, row);
        },
        onMove: (details) => _enterDrop(details.data, row),
        onLeave: (_) => _leaveDrop(),
        onAcceptWithDetails: (details) {
          _leaveDrop();
          widget.onDrop(details.data, row);
        },
        builder: (context, candidates, rejected) {
          final scheme = Theme.of(context).colorScheme;
          final dropping = _dropTargetKey == row.focusKey;
          return Semantics(
            button: true,
            label: '${row.label}グループ、'
                '${row.expanded ? '展開中' : '折りたたみ中'}',
            child: InkWell(
              onTap: () {
                widget.onFocusRow(row.focusKey);
                widget.onToggleGroup(row.groupId);
              },
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(
                  horizontal: UiTokens.space8,
                ),
                decoration: BoxDecoration(
                  color: dropping
                      ? (_dropAllowed
                          ? scheme.primaryContainer
                          : scheme.errorContainer)
                      : widget.focusedKey == row.focusKey
                          ? scheme.surfaceContainerHigh
                          : null,
                  border: dropping
                      ? Border.all(
                          color: _dropAllowed
                              ? scheme.primary
                              : scheme.error,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      row.expanded
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      size: UiTokens.iconSmall,
                    ),
                    const SizedBox(width: UiTokens.space4),
                    const Icon(
                      Icons.category_outlined,
                      size: UiTokens.iconNormal,
                    ),
                    const SizedBox(width: UiTokens.space6),
                    Expanded(
                      child: Text(
                        row.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: UiTokens.textMd,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (dropping)
                      Text(
                        _dropAllowed ? '最上位へ移動' : '移動不可',
                        style: TextStyle(
                          fontSize: UiTokens.textXs,
                          color: _dropAllowed
                              ? scheme.primary
                              : scheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _tagRow(TagTreeRow row) {
    final tag = row.tag!;
    return Draggable<Tag>(
      data: tag,
      onDragStarted: () => widget.onDragStarted(tag),
      onDragEnd: (_) => widget.onDragEnded(),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(UiTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UiTokens.space12,
            vertical: UiTokens.space8,
          ),
          child: Text(tag.name),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _tagDropTarget(row)),
      child: _tagDropTarget(row),
    );
  }

  Widget _tagDropTarget(TagTreeRow row) => DragTarget<Tag>(
        onWillAcceptWithDetails: (details) {
          _enterDrop(details.data, row);
          return widget.canDrop(details.data, row);
        },
        onMove: (details) => _enterDrop(details.data, row),
        onLeave: (_) => _leaveDrop(),
        onAcceptWithDetails: (details) {
          _leaveDrop();
          widget.onDrop(details.data, row);
        },
        builder: (context, candidates, rejected) {
          final tag = row.tag!;
          final scheme = Theme.of(context).colorScheme;
          final selected = widget.selectedTagId == tag.id;
          final focused = widget.focusedKey == row.focusKey;
          final dropping = _dropTargetKey == row.focusKey;
          final editing = widget.editingTagId == tag.id;
          final showSelection = widget.multiSelectedIds.isNotEmpty;
          final style = const TextStyle(
            fontSize: UiTokens.textMd,
            fontWeight: FontWeight.w400,
          );
          return Semantics(
            selected: selected,
            label: '${tag.name}、直接${row.directCount}件、'
                '子孫を含む${row.aggregateCount}件',
            child: GestureDetector(
              onDoubleTap: () => widget.onBeginRename(tag),
              child: InkWell(
                onTap: () {
                  widget.onFocusRow(row.focusKey);
                  widget.onSelectTag(tag);
                },
                child: Container(
                  height: 38,
                  padding: EdgeInsets.only(
                    left: UiTokens.space8 + row.depth * 20,
                    right: UiTokens.space4,
                  ),
                  decoration: BoxDecoration(
                    color: dropping
                        ? (_dropAllowed
                            ? scheme.primaryContainer
                            : scheme.errorContainer)
                        : selected
                            ? scheme.secondaryContainer
                            : focused
                                ? scheme.surfaceContainerHigh
                                : null,
                    border: focused
                        ? Border(
                            left: BorderSide(
                              color: scheme.primary,
                              width: 2,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: row.hasChildren
                            ? IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                tooltip: row.expanded ? '折りたたむ' : '展開する',
                                onPressed: () => widget.onToggleTag(tag),
                                icon: Icon(
                                  row.expanded
                                      ? Icons.expand_more
                                      : Icons.chevron_right,
                                  size: UiTokens.iconSmall,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (showSelection)
                        SizedBox(
                          width: 28,
                          child: Checkbox(
                            value: widget.multiSelectedIds.contains(tag.id),
                            onChanged: (_) =>
                                widget.onToggleMultiSelect(tag),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                      else ...[
                        const Icon(
                          Icons.sell_outlined,
                          size: UiTokens.iconSmall,
                        ),
                        const SizedBox(width: UiTokens.space6),
                      ],
                      Expanded(
                        child: editing
                            ? TextField(
                                controller: widget.editController,
                                autofocus: true,
                                style: style,
                                decoration: InputDecoration(
                                  isDense: true,
                                  errorText: widget.editError,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: UiTokens.space4,
                                    vertical: UiTokens.space6,
                                  ),
                                ),
                                onSubmitted: (_) =>
                                    widget.onSubmitRename(tag),
                                onTapOutside: (_) =>
                                    widget.onSubmitRename(tag),
                                onEditingComplete: () {},
                              )
                            : RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: _highlight(tag.name, style),
                              ),
                      ),
                      if (dropping)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: UiTokens.space8,
                          ),
                          child: Text(
                            _dropAllowed ? '子にする' : '移動不可',
                            style: TextStyle(
                              fontSize: UiTokens.textXs,
                              color: _dropAllowed
                                  ? scheme.primary
                                  : scheme.error,
                            ),
                          ),
                        )
                      else ...[
                        InkWell(
                          onTap: () => widget.onShowDirect(tag),
                          child: Text(
                            '${row.directCount}',
                            style: TextStyle(
                              fontSize: UiTokens.textSm,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          ' / ',
                          style: TextStyle(
                            fontSize: UiTokens.textSm,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        InkWell(
                          onTap: () => widget.onShowAggregate(tag),
                          child: Text(
                            '子孫含む${row.aggregateCount}',
                            style: TextStyle(
                              fontSize: UiTokens.textSm,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: PopupMenuButton<String>(
                            tooltip: 'タグ操作',
                            padding: EdgeInsets.zero,
                            iconSize: UiTokens.iconNormal,
                            onSelected: (action) =>
                                widget.onMenuAction(tag, action),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('名前変更'),
                              ),
                              PopupMenuItem(
                                value: 'move',
                                child: Text('親・グループを変更'),
                              ),
                              PopupMenuItem(
                                value: 'root',
                                child: Text('最上位へ移動'),
                              ),
                              PopupMenuItem(
                                value: 'merge',
                                child: Text('統合'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('削除'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}
