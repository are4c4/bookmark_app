import 'object_body.dart';
import 'object_body_block_contracts.dart';

enum ObjectBodyBlockPresentationKind {
  text,
  heading,
  checklist,
  code,
  divider,
  objectReference,
  databaseView,
  asset,
  unknown,
}

/// Widget-independent presentation metadata for one Body block.
///
/// Real full-page/peek editors can share this interpretation while still
/// deciding their own Flutter layout and interaction chrome.
class ObjectBodyBlockPresentation {
  const ObjectBodyBlockPresentation({
    required this.kind,
    required this.block,
    this.headingLevel,
    this.checked,
    this.language,
  });

  final ObjectBodyBlockPresentationKind kind;
  final ObjectBodyBlock block;
  final int? headingLevel;
  final bool? checked;
  final String? language;

  bool get isEditableText => switch (kind) {
        ObjectBodyBlockPresentationKind.text ||
        ObjectBodyBlockPresentationKind.heading ||
        ObjectBodyBlockPresentationKind.checklist ||
        ObjectBodyBlockPresentationKind.code => true,
        ObjectBodyBlockPresentationKind.divider ||
        ObjectBodyBlockPresentationKind.objectReference ||
        ObjectBodyBlockPresentationKind.databaseView ||
        ObjectBodyBlockPresentationKind.asset ||
        ObjectBodyBlockPresentationKind.unknown => false,
      };
}

class ObjectBodyBlockPresenter {
  const ObjectBodyBlockPresenter();

  ObjectBodyBlockPresentation present(ObjectBodyBlock block) {
    switch (block.type) {
      case ObjectBodyBlockType.heading:
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.heading,
          block: block,
          headingLevel: _int(block.attributes[ObjectBodyBlockAttribute.level]),
        );
      case ObjectBodyBlockType.checklist:
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.checklist,
          block: block,
          checked: block.attributes[ObjectBodyBlockAttribute.checked] as bool?,
        );
      case ObjectBodyBlockType.code:
        final language = block.attributes[ObjectBodyBlockAttribute.language];
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.code,
          block: block,
          language: language == null ? null : '$language',
        );
      case ObjectBodyBlockType.divider:
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.divider,
          block: block,
        );
      case ObjectBodyBlockType.objectReference:
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.objectReference,
          block: block,
        );
      case ObjectBodyBlockType.databaseView:
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.databaseView,
          block: block,
        );
      case ObjectBodyBlockType.image:
      case ObjectBodyBlockType.file:
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.asset,
          block: block,
        );
      case ObjectBodyBlockType.paragraph:
      case ObjectBodyBlockType.bulletedListItem:
      case ObjectBodyBlockType.numberedListItem:
      case ObjectBodyBlockType.quote:
      case ObjectBodyBlockType.callout:
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.text,
          block: block,
        );
      default:
        return ObjectBodyBlockPresentation(
          kind: ObjectBodyBlockPresentationKind.unknown,
          block: block,
        );
    }
  }

  List<ObjectBodyBlockPresentation> presentDocument(
    ObjectBodyDocument document,
  ) =>
      document.blocks.map(present).toList(growable: false);

  int? _int(dynamic value) => value is int ? value : int.tryParse('$value');
}
