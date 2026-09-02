import 'package:flutter/material.dart';

import '../../../../domain/object_body.dart';
import '../../../../domain/object_body_block_presentation.dart';
import 'object_body_block_view.dart';

/// Shared renderer/editor shell for a whole Object Body document.
///
/// Hosts can progressively add persistence and navigation around individual
/// blocks while retaining one canonical block interpretation path.
class ObjectBodyDocumentView extends StatelessWidget {
  const ObjectBodyDocumentView({
    super.key,
    required this.document,
    this.presenter = const ObjectBodyBlockPresenter(),
    this.onTextChanged,
    this.onChecklistChanged,
    this.onObjectReferenceTap,
    this.onDatabaseViewTap,
    this.onAssetTap,
    this.emptyBuilder,
  });

  final ObjectBodyDocument document;
  final ObjectBodyBlockPresenter presenter;
  final void Function(ObjectBodyBlock block, String text)? onTextChanged;
  final void Function(ObjectBodyBlock block, bool checked)? onChecklistChanged;
  final ValueChanged<ObjectBodyBlock>? onObjectReferenceTap;
  final ValueChanged<ObjectBodyBlock>? onDatabaseViewTap;
  final ValueChanged<ObjectBodyBlock>? onAssetTap;
  final WidgetBuilder? emptyBuilder;

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
          ObjectBodyBlockView(
            key: ValueKey('object-body-block-${presentation.block.id}'),
            presentation: presentation,
            onTextChanged: onTextChanged == null
                ? null
                : (text) => onTextChanged!(presentation.block, text),
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
          ),
      ],
    );
  }
}
