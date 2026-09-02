import 'object_body.dart';
import 'object_body_block_contracts.dart';

/// Validation for block kinds that the current app creates directly.
///
/// Unknown block kinds are deliberately accepted: forward-compatible Body
/// content must keep round-tripping even when this app version cannot render it
/// specially yet.
class ObjectBodyBlockValidator {
  const ObjectBodyBlockValidator();

  void validate(ObjectBodyBlock block) {
    if (block.id.trim().isEmpty) {
      throw const FormatException('Object Body block id cannot be empty.');
    }
    if (!block.isKnownType) return;

    switch (block.type) {
      case ObjectBodyBlockType.heading:
        final level = _int(block.attributes[ObjectBodyBlockAttribute.level]);
        if (level == null || level < 1 || level > 3) {
          throw const FormatException('Heading level must be between 1 and 3.');
        }
      case ObjectBodyBlockType.checklist:
        if (block.attributes[ObjectBodyBlockAttribute.checked] is! bool) {
          throw const FormatException('Checklist checked must be a bool.');
        }
      case ObjectBodyBlockType.objectReference:
        _requirePositive(
          block.attributes[ObjectBodyBlockAttribute.objectId],
          'objectId',
        );
      case ObjectBodyBlockType.databaseView:
        _requirePositive(
          block.attributes[ObjectBodyBlockAttribute.databaseId],
          'databaseId',
        );
        final viewId = block.attributes[ObjectBodyBlockAttribute.viewId];
        if (viewId != null) _requirePositive(viewId, 'viewId');
      case ObjectBodyBlockType.image:
      case ObjectBodyBlockType.file:
        _requirePositive(
          block.attributes[ObjectBodyBlockAttribute.assetId],
          'assetId',
        );
      case ObjectBodyBlockType.paragraph:
      case ObjectBodyBlockType.bulletedListItem:
      case ObjectBodyBlockType.numberedListItem:
      case ObjectBodyBlockType.quote:
      case ObjectBodyBlockType.callout:
      case ObjectBodyBlockType.code:
      case ObjectBodyBlockType.divider:
        break;
      default:
        break;
    }
  }

  void validateDocument(ObjectBodyDocument document) {
    final ids = <String>{};
    for (final block in document.blocks) {
      if (!ids.add(block.id)) {
        throw FormatException('Duplicate Object Body block id: ${block.id}');
      }
      validate(block);
    }
  }

  void _requirePositive(dynamic value, String field) {
    final parsed = _int(value);
    if (parsed == null || parsed <= 0) {
      throw FormatException('$field must be a positive integer.');
    }
  }

  int? _int(dynamic value) =>
      value is int ? value : int.tryParse('${value ?? ''}');
}
