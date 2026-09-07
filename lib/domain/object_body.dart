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
    if (value is! Map) {
      throw const FormatException('Object body document must be a JSON object.');
    }
    final rawVersion = value['version'];
    if (value.containsKey('version') && rawVersion is! int) {
      throw const FormatException('Object body version must be an integer.');
    }
    final rawBlocks = value['blocks'];
    if (value.containsKey('blocks') && rawBlocks is! List) {
      throw const FormatException('Object body blocks must be a JSON array.');
    }
    final blocks = rawBlocks is List
        ? rawBlocks
            .map(ObjectBodyBlock.fromJson)
            .whereType<ObjectBodyBlock>()
            .toList(growable: false)
        : const <ObjectBodyBlock>[];
    _validateBlockStructure(blocks);
    return ObjectBodyDocument(
      version: rawVersion is int ? rawVersion : currentVersion,
      blocks: blocks,
    );
  }

  Map<String, dynamic> toJson() {
    _validateBlockStructure(blocks);
    return <String, dynamic>{
      'version': version,
      'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
    };
  }

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

  static void _validateBlockStructure(List<ObjectBodyBlock> blocks) {
    final ids = <String>{};
    for (final block in blocks) {
      final normalizedId = block.id.trim();
      final normalizedType = block.type.trim();
      if (normalizedId.isEmpty || normalizedType.isEmpty) {
        throw const FormatException(
          'Object body block requires non-empty id and type.',
        );
      }
      if (normalizedId != block.id || normalizedType != block.type) {
        throw const FormatException(
          'Object body block id and type must already be normalized.',
        );
      }
      if (!ids.add(normalizedId)) {
        throw FormatException(
          'Object body block id $normalizedId is duplicated.',
        );
      }
    }
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
    final rawId = value['id'];
    final rawType = value['type'];
    if (rawId is! String || rawType is! String) {
      throw const FormatException(
        'Object body block id and type must be strings.',
      );
    }
    final id = rawId.trim();
    final type = rawType.trim();
    if (id.isEmpty || type.isEmpty) {
      throw const FormatException('Object body block requires id and type.');
    }

    final rawText = value['text'];
    if (value.containsKey('text') && rawText != null && rawText is! String) {
      throw const FormatException('Object body block text must be a string.');
    }

    final rawAttributes = value['attributes'];
    if (value.containsKey('attributes') && rawAttributes is! Map) {
      throw const FormatException(
        'Object body block attributes must be a JSON object.',
      );
    }
    if (rawAttributes is Map &&
        rawAttributes.keys.any((key) => key is! String)) {
      throw const FormatException(
        'Object body block attribute keys must be strings.',
      );
    }

    return ObjectBodyBlock(
      id: id,
      type: type,
      text: rawText as String?,
      attributes: rawAttributes is Map
          ? rawAttributes.map(
              (key, item) => MapEntry(key as String, item),
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
