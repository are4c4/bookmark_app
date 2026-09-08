import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final presentation in presentations)
          Column(
            key: ValueKey('object-body-entry-${presentation.block.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ObjectBodyBlockView(
                key: ValueKey('object-body-block-${presentation.block.id}'),
                presentation: presentation,
                onTextChanged: onTextChanged == null
                    ? null
                    : (text) => onTextChanged!(presentation.block, text),
                onParagraphSplit: onParagraphSplit == null
                    ? null
                    : (selection) =>
                          onParagraphSplit!(presentation.block, selection),
                onParagraphMergeWithPrevious:
                    onParagraphMergeWithPrevious == null
                    ? null
                    : () => onParagraphMergeWithPrevious!(presentation.block),
                onChecklistChanged: onChecklistChanged == null
                    ? null
                    : (checked) =>
                          onChecklistChanged!(presentation.block, checked),
                onObjectReferenceTap: onObjectReferenceTap == null
                    ? null
                    : () => onObjectReferenceTap!(presentation.block),
                onDatabaseViewTap: onDatabaseViewTap == null
                    ? null
                    : () => onDatabaseViewTap!(presentation.block),
                onAssetTap: onAssetTap == null
                    ? null
                    : () => onAssetTap!(presentation.block),
                autofocus: presentation.block.id == autofocusBlockId,
                autofocusOffset: presentation.block.id == autofocusBlockId
                    ? autofocusOffset
                    : null,
              ),
              if (blockActionsBuilder != null)
                blockActionsBuilder!(
                  context,
                  presentation.block,
                  positionResolver.resolve(document, presentation.block.id),
                ),
            ],
          ),
      ],
    );
  }
}
