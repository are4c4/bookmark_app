enum ObjectTypeKind {
  system,
  custom,
}

enum ObjectPropertyType {
  title,
  text,
  number,
  checkbox,
  date,
  url,
  select,
  multiSelect,
  objectRelation,
  image,
  file,
  rating,
  createdTime,
  updatedTime,
  formula,
  rollup,
}

class ObjectPropertyDefinition {
  const ObjectPropertyDefinition({
    required this.id,
    required this.objectTypeId,
    required this.name,
    required this.type,
    required this.sortOrder,
    this.config = const <String, dynamic>{},
  });

  final int id;
  final int objectTypeId;
  final String name;
  final ObjectPropertyType type;
  final int sortOrder;
  final Map<String, dynamic> config;

  bool get isRelation => type == ObjectPropertyType.objectRelation;

  int? get targetObjectTypeId {
    final value = config['targetObjectTypeId'];
    return value is int ? value : int.tryParse('$value');
  }

  bool get allowsMultipleRelations => config['multiple'] == true;

  String get storageType => switch (type) {
        ObjectPropertyType.title => 'text',
        ObjectPropertyType.text => 'text',
        ObjectPropertyType.number => 'number',
        ObjectPropertyType.checkbox => 'checkbox',
        ObjectPropertyType.date => 'date',
        ObjectPropertyType.url => 'url',
        ObjectPropertyType.select => 'select',
        ObjectPropertyType.multiSelect => 'multiSelect',
        ObjectPropertyType.objectRelation => 'relation',
        ObjectPropertyType.image => 'image',
        ObjectPropertyType.file => 'file',
        ObjectPropertyType.rating => 'rating',
        ObjectPropertyType.createdTime => 'createdTime',
        ObjectPropertyType.updatedTime => 'updatedTime',
        ObjectPropertyType.formula => 'formula',
        ObjectPropertyType.rollup => 'rollup',
      };

  static ObjectPropertyType fromStorageType(String value) => switch (value) {
        'title' => ObjectPropertyType.title,
        'text' => ObjectPropertyType.text,
        'number' => ObjectPropertyType.number,
        'checkbox' => ObjectPropertyType.checkbox,
        'date' => ObjectPropertyType.date,
        'url' => ObjectPropertyType.url,
        'select' => ObjectPropertyType.select,
        'multiSelect' => ObjectPropertyType.multiSelect,
        'relation' => ObjectPropertyType.objectRelation,
        'image' => ObjectPropertyType.image,
        'file' => ObjectPropertyType.file,
        'rating' => ObjectPropertyType.rating,
        'createdTime' => ObjectPropertyType.createdTime,
        'updatedTime' => ObjectPropertyType.updatedTime,
        'formula' => ObjectPropertyType.formula,
        'rollup' => ObjectPropertyType.rollup,
        _ => ObjectPropertyType.text,
      };
}

class AppObjectType {
  const AppObjectType({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.icon,
    required this.kind,
    required this.sortOrder,
    this.properties = const <ObjectPropertyDefinition>[],
  });

  final int id;
  final int workspaceId;
  final String name;
  final String icon;
  final ObjectTypeKind kind;
  final int sortOrder;
  final List<ObjectPropertyDefinition> properties;

  String get key => 'objectType:$id';

  AppObjectType copyWith({
    List<ObjectPropertyDefinition>? properties,
  }) {
    return AppObjectType(
      id: id,
      workspaceId: workspaceId,
      name: name,
      icon: icon,
      kind: kind,
      sortOrder: sortOrder,
      properties: properties ?? this.properties,
    );
  }
}

class AppObject {
  const AppObject({
    required this.id,
    required this.objectTypeId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.values = const <int, dynamic>{},
  });

  final int id;
  final int objectTypeId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<int, dynamic> values;

  dynamic valueFor(int propertyId) => values[propertyId];

  AppObject copyWith({
    String? title,
    Map<int, dynamic>? values,
  }) {
    return AppObject(
      id: id,
      objectTypeId: objectTypeId,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      values: values ?? this.values,
    );
  }
}

class ObjectRelationValue {
  const ObjectRelationValue({required this.objectIds});

  factory ObjectRelationValue.single(int objectId) =>
      ObjectRelationValue(objectIds: <int>[objectId]);

  factory ObjectRelationValue.fromJson(dynamic value) {
    if (value is int) return ObjectRelationValue.single(value);
    if (value is List) {
      return ObjectRelationValue(
        objectIds: value
            .map((item) => item is int ? item : int.tryParse('$item'))
            .whereType<int>()
            .toList(growable: false),
      );
    }
    if (value is Map) {
      final raw = value['objectIds'];
      if (raw is List) {
        return ObjectRelationValue.fromJson(raw);
      }
    }
    return const ObjectRelationValue(objectIds: <int>[]);
  }

  final List<int> objectIds;

  bool get isEmpty => objectIds.isEmpty;
  bool get isSingle => objectIds.length == 1;
  int? get singleOrNull => isSingle ? objectIds.single : null;

  dynamic toJson({required bool multiple}) =>
      multiple ? objectIds : singleOrNull;
}
