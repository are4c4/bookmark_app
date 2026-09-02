enum ObjectGroupMode {
  property,
}

class ObjectGroupRule {
  const ObjectGroupRule({
    required this.propertyId,
    this.includeEmpty = true,
  });

  final int propertyId;
  final bool includeEmpty;

  Map<String, dynamic> toJson() => {
        'propertyId': propertyId,
        'includeEmpty': includeEmpty,
      };

  static ObjectGroupRule? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final idRaw = raw['propertyId'];
    final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
    if (id == null) return null;
    return ObjectGroupRule(
      propertyId: id,
      includeEmpty: raw['includeEmpty'] != false,
    );
  }
}

class ObjectGroupBucket<T> {
  const ObjectGroupBucket({
    required this.key,
    required this.label,
    required this.items,
    required this.isEmptyGroup,
  });

  final String key;
  final String label;
  final List<T> items;
  final bool isEmptyGroup;
}
