import 'package:flutter/material.dart';

import '../../../../domain/object_body_block_contracts.dart';
import '../../../../domain/object_body_block_presentation.dart';

/// Shared Flutter renderer/editor for one Object Body block.
///
/// This widget deliberately depends on the widget-independent presentation
/// model rather than reinterpreting persisted Body payloads in each host.
/// Supplying [onTextChanged] turns known text-like blocks into inline editors;
/// omitting it keeps the same component read-only.
class ObjectBodyBlockView extends StatelessWidget {
  const ObjectBodyBlockView({
    super.key,
    required this.presentation,
    this.onTextChanged,
    this.onChecklistChanged,
    this.onObjectReferenceTap,
    this.onDatabaseViewTap,
    this.onAssetTap,
  });

  final ObjectBodyBlockPresentation presentation;
  final ValueChanged<String>? onTextChanged;
  final ValueChanged<bool>? onChecklistChanged;
  final VoidCallback? onObjectReferenceTap;
  final VoidCallback? onDatabaseViewTap;
  final VoidCallback? onAssetTap;

  @override
  Widget build(BuildContext context) {
    final block = presentation.block;
    switch (presentation.kind) {
      case ObjectBodyBlockPresentationKind.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _textControl(
            initialValue: block.text ?? '',
            onChanged: onTextChanged,
          ),
        );
      case ObjectBodyBlockPresentationKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: _textControl(
            initialValue: block.text ?? '',
            onChanged: onTextChanged,
            style: _headingStyle(context, presentation.headingLevel),
          ),
        );
      case ObjectBodyBlockPresentationKind.checklist:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: presentation.checked ?? false,
              onChanged: onChecklistChanged == null
                  ? null
                  : (value) => onChecklistChanged!(value ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _textControl(
                  initialValue: block.text ?? '',
                  onChanged: onTextChanged,
                ),
              ),
            ),
          ],
        );
      case ObjectBodyBlockPresentationKind.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (presentation.language case final language?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    language,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              _textControl(
                initialValue: block.text ?? '',
                onChanged: onTextChanged,
                maxLines: null,
              ),
            ],
          ),
        );
      case ObjectBodyBlockPresentationKind.divider:
        return const Divider();
      case ObjectBodyBlockPresentationKind.objectReference:
        return _ReferenceTile(
          icon: Icons.link,
          label: block.text?.trim().isNotEmpty == true
              ? block.text!.trim()
              : 'Object #${block.referencedObjectId ?? '?'}',
          onTap: onObjectReferenceTap,
        );
      case ObjectBodyBlockPresentationKind.databaseView:
        final databaseId = block.referencedDatabaseId;
        final viewId = block.referencedViewId;
        return _ReferenceTile(
          icon: Icons.view_list_outlined,
          label: viewId == null
              ? 'Database #${databaseId ?? '?'}'
              : 'Database #${databaseId ?? '?'} · View #$viewId',
          onTap: onDatabaseViewTap,
        );
      case ObjectBodyBlockPresentationKind.asset:
        final isImage = block.type == ObjectBodyBlockType.image;
        final caption = block.attributes[ObjectBodyBlockAttribute.caption];
        return _ReferenceTile(
          icon: isImage ? Icons.image_outlined : Icons.attach_file,
          label: caption is String && caption.trim().isNotEmpty
              ? caption.trim()
              : '${isImage ? 'Image' : 'File'} #${block.referencedAssetId ?? '?'}',
          onTap: onAssetTap,
        );
      case ObjectBodyBlockPresentationKind.unknown:
        return _ReferenceTile(
          icon: Icons.extension_outlined,
          label: 'Unsupported block: ${block.type}',
        );
    }
  }

  Widget _textControl({
    required String initialValue,
    required ValueChanged<String>? onChanged,
    TextStyle? style,
    int? maxLines = 1,
  }) {
    if (onChanged == null) {
      return Text(initialValue, style: style);
    }
    return TextFormField(
      key: ValueKey('body-text-${presentation.block.id}'),
      initialValue: initialValue,
      maxLines: maxLines,
      style: style,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: onChanged,
    );
  }

  TextStyle? _headingStyle(BuildContext context, int? level) {
    final textTheme = Theme.of(context).textTheme;
    return switch (level) {
      1 => textTheme.headlineSmall,
      2 => textTheme.titleLarge,
      3 => textTheme.titleMedium,
      _ => textTheme.titleLarge,
    };
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
