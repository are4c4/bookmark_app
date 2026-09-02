/// Versioned, block-oriented content belonging to an Object.
///
/// This model deliberately does not depend on database/view presentation code.
/// Persisted documents can start with simple paragraph blocks and gain richer
/// block types later without replacing the Object content contract.
class ObjectBodyDocument {
  const ObjectBodyDocument({
    this.version = currentVersion,
    this.blocks = const <ObjectBodyBlock>[],
  });

  static const int currentVersion = 1;

  final int version;
  final List<ObjectBodyBlock> blocks;

  factory ObjectBodyDocument.fromJson(dynamic value) {
    if (value is! Map) return const ObjectBodyDocument();
    final rawVersion = value['version'];
    final rawBlocks = value['blocks'];
    return ObjectBodyDocument(
      version: rawVersion is int ? rawVersion : currentVersion,
      blocks: rawBlocks is List
          ? rawBlocks
              .map(ObjectBodyBlock.fromJson)
              .whereType<ObjectBodyBlock>()
              .toList(growable: false)
          : const <ObjectBodyBlock>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
      };

  bool get isEmpty => blocks.isEmpty;

  ObjectBodyDocument copyWith({
    int? version,
    List<ObjectBodyBlock>? blocks,
  }) {
    return ObjectBodyDocument(
      version: version ?? this.version,
      blocks: blocks ?? this.blocks,
    );
  }
}

/// Block type names are persisted as strings so future/unknown kinds can be
/// round-tripped instead of being silently coerced into a current enum value.
class ObjectBodyBlock {
  const ObjectBodyBlock({
    required this.id,
    required this.type,
    this.text,
    this.attributes = const <String, dynamic>{},
  });

  final String id;
  final String type;
  final String? text;
  final Map<String, dynamic> attributes;

  factory ObjectBodyBlock.paragraph({
    required String id,
    String text = '',
  }) {
    return ObjectBodyBlock(id: id, type: 'paragraph', text: text);
  }

  factory ObjectBodyBlock.fromJson(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Object body block must be a map.');
    }
    final id = '${value['id'] ?? ''}'.trim();
    final type = '${value['type'] ?? ''}'.trim();
    if (id.isEmpty || type.isEmpty) {
      throw const FormatException('Object body block requires id and type.');
    }
    final rawAttributes = value['attributes'];
    return ObjectBodyBlock(
      id: id,
      type: type,
      text: value['text'] == null ? null : '${value['text']}',
      attributes: rawAttributes is Map
          ? rawAttributes.map(
              (key, item) => MapEntry('$key', item),
            )
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        if (text != null) 'text': text,
        if (attributes.isNotEmpty) 'attributes': attributes,
      };

  ObjectBodyBlock copyWith({
    String? id,
    String? type,
    String? text,
    Map<String, dynamic>? attributes,
  }) {
    return ObjectBodyBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      attributes: attributes ?? this.attributes,
    );
  }
}
