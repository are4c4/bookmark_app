import 'object_body.dart';

/// Stable, known block type names for Object Body content.
///
/// Persisted block types remain strings in [ObjectBodyBlock] so unknown future
/// kinds still round-trip safely. This class only centralizes the block kinds
/// that the current app understands well enough to create/validate.
abstract final class ObjectBodyBlockType {
  static const paragraph = 'paragraph';
  static const heading = 'heading';
  static const bulletedListItem = 'bulletedListItem';
  static const numberedListItem = 'numberedListItem';
  static const checklist = 'checklist';
  static const quote = 'quote';
  static const callout = 'callout';
  static const code = 'code';
  static const divider = 'divider';
  static const image = 'image';
  static const file = 'file';
  static const objectReference = 'objectReference';
  static const databaseView = 'databaseView';

  static const known = <String>{
    paragraph,
    heading,
    bulletedListItem,
    numberedListItem,
    checklist,
    quote,
    callout,
    code,
    divider,
    image,
    file,
    objectReference,
    databaseView,
  };
}

abstract final class ObjectBodyBlockAttribute {
  static const level = 'level';
  static const checked = 'checked';
  static const language = 'language';
  static const icon = 'icon';
  static const objectId = 'objectId';
  static const databaseId = 'databaseId';
  static const viewId = 'viewId';
  static const assetId = 'assetId';
  static const caption = 'caption';
}

/// Creates currently-supported rich Body blocks while keeping their persisted
/// representation compatible with the open string-based [ObjectBodyBlock]
/// model.
class ObjectBodyBlockFactory {
  const ObjectBodyBlockFactory();

  ObjectBodyBlock paragraph({required String id, String text = ''}) =>
      ObjectBodyBlock(id: id, type: ObjectBodyBlockType.paragraph, text: text);

  ObjectBodyBlock heading({
    required String id,
    required int level,
    String text = '',
  }) {
    if (level < 1 || level > 3) {
      throw RangeError.range(level, 1, 3, 'level');
    }
    return ObjectBodyBlock(
      id: id,
      type: ObjectBodyBlockType.heading,
      text: text,
      attributes: <String, dynamic>{ObjectBodyBlockAttribute.level: level},
    );
  }

  ObjectBodyBlock checklist({
    required String id,
    String text = '',
    bool checked = false,
  }) =>
      ObjectBodyBlock(
        id: id,
        type: ObjectBodyBlockType.checklist,
        text: text,
        attributes: <String, dynamic>{ObjectBodyBlockAttribute.checked: checked},
      );

  ObjectBodyBlock code({
    required String id,
    String text = '',
    String? language,
  }) =>
      ObjectBodyBlock(
        id: id,
        type: ObjectBodyBlockType.code,
        text: text,
        attributes: <String, dynamic>{
          if (language != null && language.trim().isNotEmpty)
            ObjectBodyBlockAttribute.language: language.trim(),
        },
      );

  ObjectBodyBlock divider({required String id}) => ObjectBodyBlock(
        id: id,
        type: ObjectBodyBlockType.divider,
      );

  ObjectBodyBlock objectReference({
    required String id,
    required int objectId,
    String? text,
  }) {
    _requirePositiveId(objectId, 'objectId');
    return ObjectBodyBlock(
      id: id,
      type: ObjectBodyBlockType.objectReference,
      text: text,
      attributes: <String, dynamic>{ObjectBodyBlockAttribute.objectId: objectId},
    );
  }

  ObjectBodyBlock databaseView({
    required String id,
    required int databaseId,
    int? viewId,
  }) {
    _requirePositiveId(databaseId, 'databaseId');
    if (viewId != null) _requirePositiveId(viewId, 'viewId');
    return ObjectBodyBlock(
      id: id,
      type: ObjectBodyBlockType.databaseView,
      attributes: <String, dynamic>{
        ObjectBodyBlockAttribute.databaseId: databaseId,
        if (viewId != null) ObjectBodyBlockAttribute.viewId: viewId,
      },
    );
  }

  ObjectBodyBlock asset({
    required String id,
    required String type,
    required int assetId,
    String? caption,
  }) {
    if (type != ObjectBodyBlockType.image && type != ObjectBodyBlockType.file) {
      throw ArgumentError.value(type, 'type', 'Expected image or file.');
    }
    _requirePositiveId(assetId, 'assetId');
    return ObjectBodyBlock(
      id: id,
      type: type,
      attributes: <String, dynamic>{
        ObjectBodyBlockAttribute.assetId: assetId,
        if (caption != null && caption.isNotEmpty)
          ObjectBodyBlockAttribute.caption: caption,
      },
    );
  }

  void _requirePositiveId(int value, String name) {
    if (value <= 0) throw ArgumentError.value(value, name, 'Must be positive.');
  }
}

/// Typed, read-only accessors for reference-bearing Body blocks.
extension ObjectBodyBlockReferenceAccess on ObjectBodyBlock {
  bool get isKnownType => ObjectBodyBlockType.known.contains(type);

  int? get referencedObjectId =>
      type == ObjectBodyBlockType.objectReference
          ? _positiveInt(attributes[ObjectBodyBlockAttribute.objectId])
          : null;

  int? get referencedDatabaseId => type == ObjectBodyBlockType.databaseView
      ? _positiveInt(attributes[ObjectBodyBlockAttribute.databaseId])
      : null;

  int? get referencedViewId => type == ObjectBodyBlockType.databaseView
      ? _positiveInt(attributes[ObjectBodyBlockAttribute.viewId])
      : null;

  int? get referencedAssetId =>
      type == ObjectBodyBlockType.image || type == ObjectBodyBlockType.file
          ? _positiveInt(attributes[ObjectBodyBlockAttribute.assetId])
          : null;
}

int? _positiveInt(dynamic value) {
  final parsed = value is int ? value : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}
