import 'package:flutter/material.dart';

import '../../../../domain/object_body.dart';
import '../../../../domain/object_body_block_actions.dart';
import '../../../../domain/object_body_block_presentation.dart';
import 'object_body_block_view.dart';

typedef ObjectBodyBlockActionsBuilder = Widget Function(
  BuildContext context,
  ObjectBodyBlock block,
  ObjectBodyBlockPosition position,
);

typedef ObjectBodyParagraphSplitHandler = Future<void> Function(
  ObjectBodyBlock block,
  TextSelection selection,
);

typedef ObjectBodyParagraphMergeHandler = Future<void> Function(
  ObjectBodyBlock block,
);

typedef ObjectBodyBlockReorderHandler = Future<void> Function(
  ObjectBodyBlock block,
  int toIndex,
);

/// Shared renderer/editor shell for a whole Object Body document.
///
/// Hosts can progressively add persistence and navigation around individual
/// blocks while retaining one canonical block interpretation path.
class ObjectBodyDocumentView extends StatelessWidget {
  const ObjectBodyDocumentView({
    super.key,
    required this.document,
    this.presenter = const ObjectBodyBlockPresenter(),
    this.positionResolver = const ObjectBodyBlockPositionResolver(),
    this.onTextChanged,
    this.onParagraphSplit,
    this.onParagraphMergeWithPrevious,
    this.onChecklistChanged,
    this.onObjectReferenceTap,
    this.onDatabaseViewTap,
    this.onAssetTap,
    this.onBlockReorder,
    this.blockActionsBuilder,
    this.emptyBuilder,
    this.autofocusBlockId,
    this.autofocusOffset,
  });

  final ObjectBodyDocument document;
  final ObjectBodyBlockPresenter presenter;
  final ObjectBodyBlockPositionResolver positionResolver;
  final void Function(ObjectBodyBlock block, String text)? onTextChanged;
  final ObjectBodyParagraphSplitHandler? onParagraphSplit;
  final ObjectBodyParagraphMergeHandler? onParagraphMergeWithPrevious;
  final void Function(ObjectBodyBlock block, bool checked)? onChecklistChanged;
  final ValueChanged<ObjectBodyBlock>? onObjectReferenceTap;
  final ValueChanged<ObjectBodyBlock>? onDatabaseViewTap;
  final ValueChanged<ObjectBodyBlock>? onAssetTap;
  final ObjectBodyBlockReorderHandler? onBlockReorder;
  final ObjectBodyBlockActionsBuilder? blockActionsBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? autofocusBlockId;
  final int? autofocusOffset;

  @override
  Widget build(BuildContext context) {
    if (document.blocks.isEmpty) {
      return emptyBuilder?.call(context) ??
          const SizedBox.shrink(key: ValueKey('object-body-empty'));
    }

    final presentations = presenter.presentDocument(document);
    final canReorder = onBlockReorder != null && presentations.length > 1;
    final entries = <Widget>[
      for (var index = 0; index < presentations.length; index++)
        _ObjectBodyDocumentEntry(
          key: ValueKey('object-body-entry-${presentations[index].block.id}'),
          presentation: presentations[index],
          position: positionResolver.resolve(
            document,
            presentations[index].block.id,
          ),
          index: index,
          canReorder: canReorder,
          onTextChanged: onTextChanged,
          onParagraphSplit: onParagraphSplit,
          onParagraphMergeWithPrevious: onParagraphMergeWithPrevious,
          onChecklistChanged: onChecklistChanged,
          onObjectReferenceTap: onObjectReferenceTap,
          onDatabaseViewTap: onDatabaseViewTap,
          onAssetTap: onAssetTap,
          blockActionsBuilder: blockActionsBuilder,
          autofocusBlockId: autofocusBlockId,
          autofocusOffset: autofocusOffset,
        ),
    ];

    if (!canReorder) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: entries,
      );
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        var targetIndex = newIndex;
        if (oldIndex < targetIndex) targetIndex -= 1;
        if (targetIndex == oldIndex) return;
        await onBlockReorder!(presentations[oldIndex].block, targetIndex);
      },
      children: entries,
    );
  }
}

class _ObjectBodyDocumentEntry extends StatefulWidget {
  const _ObjectBodyDocumentEntry({
    super.key,
    required this.presentation,
    required this.position,
    required this.index,
    required this.canReorder,
    this.onTextChanged,
    this.onParagraphSplit,
    this.onParagraphMergeWithPrevious,
    this.onChecklistChanged,
    this.onObjectReferenceTap,
    this.onDatabaseViewTap,
    this.onAssetTap,
    this.blockActionsBuilder,
    this.autofocusBlockId,
    this.autofocusOffset,
  });

  final ObjectBodyBlockPresentation presentation;
  final ObjectBodyBlockPosition position;
  final int index;
  final bool canReorder;
  final void Function(ObjectBodyBlock block, String text)? onTextChanged;
  final ObjectBodyParagraphSplitHandler? onParagraphSplit;
  final ObjectBodyParagraphMergeHandler? onParagraphMergeWithPrevious;
  final void Function(ObjectBodyBlock block, bool checked)? onChecklistChanged;
  final ValueChanged<ObjectBodyBlock>? onObjectReferenceTap;
  final ValueChanged<ObjectBodyBlock>? onDatabaseViewTap;
  final ValueChanged<ObjectBodyBlock>? onAssetTap;
  final ObjectBodyBlockActionsBuilder? blockActionsBuilder;
  final String? autofocusBlockId;
  final int? autofocusOffset;

  @override
  State<_ObjectBodyDocumentEntry> createState() =>
      _ObjectBodyDocumentEntryState();
}

class _ObjectBodyDocumentEntryState extends State<_ObjectBodyDocumentEntry> {
  bool _hovered = false;
  bool _focused = false;
  bool _touchActionsVisible = false;

  ObjectBodyBlock get _block => widget.presentation.block;

  bool _usesTouchChrome(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;
  }

  @override
  Widget build(BuildContext context) {
    final usesTouchChrome = _usesTouchChrome(context);
    final hasActions = widget.blockActionsBuilder != null;
    final showActions =
        hasActions && (_hovered || _focused || _touchActionsVisible);

    final blockView = ObjectBodyBlockView(
      key: ValueKey('object-body-block-${_block.id}'),
      presentation: widget.presentation,
      onTextChanged: widget.onTextChanged == null
          ? null
          : (text) => widget.onTextChanged!(_block, text),
      onParagraphSplit: widget.onParagraphSplit == null
          ? null
          : (selection) => widget.onParagraphSplit!(_block, selection),
      onParagraphMergeWithPrevious: widget.onParagraphMergeWithPrevious == null
          ? null
          : () => widget.onParagraphMergeWithPrevious!(_block),
      onChecklistChanged: widget.onChecklistChanged == null
          ? null
          : (checked) => widget.onChecklistChanged!(_block, checked),
      onObjectReferenceTap: widget.onObjectReferenceTap == null
          ? null
          : () => widget.onObjectReferenceTap!(_block),
      onDatabaseViewTap: widget.onDatabaseViewTap == null
          ? null
          : () => widget.onDatabaseViewTap!(_block),
      onAssetTap: widget.onAssetTap == null
          ? null
          : () => widget.onAssetTap!(_block),
      autofocus: _block.id == widget.autofocusBlockId,
      autofocusOffset: _block.id == widget.autofocusBlockId
          ? widget.autofocusOffset
          : null,
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (_focused == focused) return;
        setState(() => _focused = focused);
      },
      child: MouseRegion(
        onEnter: (_) {
          if (_hovered) return;
          setState(() => _hovered = true);
        },
        onExit: (_) {
          if (!_hovered) return;
          setState(() => _hovered = false);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (usesTouchChrome && hasActions)
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 40),
                    child: blockView,
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      key: ValueKey('body-block-touch-actions-${_block.id}'),
                      tooltip: _touchActionsVisible
                          ? 'ブロック操作を閉じる'
                          : 'ブロック操作を表示',
                      icon: Icon(
                        _touchActionsVisible ? Icons.close : Icons.more_horiz,
                        size: 18,
                      ),
                      onPressed: () => setState(
                        () => _touchActionsVisible = !_touchActionsVisible,
                      ),
                    ),
                  ),
                ],
              )
            else
              blockView,
            if (showActions)
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.canReorder) _buildDragHandle(context),
                    widget.blockActionsBuilder!(
                      context,
                      _block,
                      widget.position,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    final child = Tooltip(
      message: 'ブロックを並べ替え',
      child: Semantics(
        label: 'ブロックを並べ替え',
        button: true,
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.drag_indicator, size: 18),
        ),
      ),
    );

    if (_usesTouchChrome(context)) {
      return ReorderableDelayedDragStartListener(
        key: ValueKey('body-block-drag-${_block.id}'),
        index: widget.index,
        child: child,
      );
    }
    return ReorderableDragStartListener(
      key: ValueKey('body-block-drag-${_block.id}'),
      index: widget.index,
      child: child,
    );
  }
}
