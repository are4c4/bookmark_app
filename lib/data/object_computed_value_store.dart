import '../domain/object_model.dart';
import 'object_store.dart';

class ObjectComputedValueStore {
  ObjectComputedValueStore(this.objectStore);

  final ObjectStore objectStore;

  Future<dynamic> evaluate({
    required AppObject object,
    required ObjectPropertyDefinition property,
  }) async {
    return switch (property.type) {
      ObjectPropertyType.formula => _evaluateFormula(object, property),
      ObjectPropertyType.rollup => _evaluateRollup(object, property),
      _ => object.values[property.id],
    };
  }

  Future<int> createFormulaProperty({
    required int objectTypeId,
    required String name,
    required String expression,
  }) async {
    final normalized = expression.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(expression, 'expression', 'Formula cannot be empty.');
    }

    final referencedPropertyIds = <int>{};
    _FormulaParser(
      normalized,
      propertyValue: (propertyId) {
        referencedPropertyIds.add(propertyId);
        return 1;
      },
    ).parse();

    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'ObjectType does not exist.',
      );
    }
    for (final propertyId in referencedPropertyIds) {
      ObjectPropertyDefinition? referenced;
      for (final candidate in objectType.properties) {
        if (candidate.id == propertyId) {
          referenced = candidate;
          break;
        }
      }
      if (referenced == null) {
        throw ArgumentError.value(
          propertyId,
          'expression',
          'Formula references a property outside this ObjectType.',
        );
      }
      if (referenced.type != ObjectPropertyType.number &&
          referenced.type != ObjectPropertyType.rating) {
        throw ArgumentError.value(
          propertyId,
          'expression',
          'Formula references must point to numeric properties.',
        );
      }
    }

    return objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: name,
      type: ObjectPropertyType.formula,
      config: <String, dynamic>{'expression': normalized},
    );
  }

  Future<int> createRollupProperty({
    required int objectTypeId,
    required String name,
    required int relationPropertyId,
    int? targetPropertyId,
    required String aggregation,
  }) async {
    const supported = <String>{'count', 'sum', 'average', 'min', 'max'};
    if (!supported.contains(aggregation)) {
      throw ArgumentError.value(
        aggregation,
        'aggregation',
        'Unsupported rollup aggregation.',
      );
    }
    if (aggregation != 'count' && targetPropertyId == null) {
      throw ArgumentError('targetPropertyId is required for $aggregation.');
    }

    final sourceType = await objectStore.getObjectType(objectTypeId);
    if (sourceType == null) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'ObjectType does not exist.',
      );
    }
    ObjectPropertyDefinition? relationProperty;
    for (final candidate in sourceType.properties) {
      if (candidate.id == relationPropertyId) {
        relationProperty = candidate;
        break;
      }
    }
    if (relationProperty == null || !relationProperty.isRelation) {
      throw ArgumentError.value(
        relationPropertyId,
        'relationPropertyId',
        'Rollup must reference a Relation property on this ObjectType.',
      );
    }

    if (aggregation != 'count') {
      final targetTypeId = relationProperty.targetObjectTypeId;
      if (targetTypeId == null) {
        throw StateError('Relation property has no target ObjectType.');
      }
      final targetType = await objectStore.getObjectType(targetTypeId);
      if (targetType == null) {
        throw StateError('Relation target ObjectType does not exist.');
      }
      ObjectPropertyDefinition? targetProperty;
      for (final candidate in targetType.properties) {
        if (candidate.id == targetPropertyId) {
          targetProperty = candidate;
          break;
        }
      }
      if (targetProperty == null ||
          (targetProperty.type != ObjectPropertyType.number &&
              targetProperty.type != ObjectPropertyType.rating)) {
        throw ArgumentError.value(
          targetPropertyId,
          'targetPropertyId',
          'Rollup numeric aggregations require a numeric target property.',
        );
      }
    }

    return objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: name,
      type: ObjectPropertyType.rollup,
      config: <String, dynamic>{
        'relationPropertyId': relationPropertyId,
        if (targetPropertyId != null) 'targetPropertyId': targetPropertyId,
        'aggregation': aggregation,
      },
    );
  }

  num? _evaluateFormula(
    AppObject object,
    ObjectPropertyDefinition property,
  ) {
    final expression = '${property.config['expression'] ?? ''}'.trim();
    if (expression.isEmpty) return null;
    final parser = _FormulaParser(
      expression,
      propertyValue: (propertyId) {
        final value = object.values[propertyId];
        return value is num ? value : num.tryParse('$value');
      },
    );
    return parser.parse();
  }

  Future<dynamic> _evaluateRollup(
    AppObject object,
    ObjectPropertyDefinition property,
  ) async {
    final relationPropertyId = _intConfig(property.config['relationPropertyId']);
    if (relationPropertyId == null) return null;
    final objectType = await objectStore.getObjectType(object.objectTypeId);
    if (objectType == null) return null;
    ObjectPropertyDefinition? relationProperty;
    for (final candidate in objectType.properties) {
      if (candidate.id == relationPropertyId) {
        relationProperty = candidate;
        break;
      }
    }
    if (relationProperty == null || !relationProperty.isRelation) return null;

    final related = await objectStore.resolveRelation(
      relationProperty,
      object.values[relationProperty.id],
    );
    final aggregation = '${property.config['aggregation'] ?? 'count'}';
    if (aggregation == 'count') return related.length;

    final targetPropertyId = _intConfig(property.config['targetPropertyId']);
    if (targetPropertyId == null) return null;
    final values = related
        .map((item) => item.values[targetPropertyId])
        .map((value) => value is num ? value : num.tryParse('$value'))
        .whereType<num>()
        .toList(growable: false);
    if (values.isEmpty) return null;

    return switch (aggregation) {
      'sum' => values.fold<num>(0, (total, value) => total + value),
      'average' => values.fold<num>(0, (total, value) => total + value) /
          values.length,
      'min' => values.reduce((a, b) => a < b ? a : b),
      'max' => values.reduce((a, b) => a > b ? a : b),
      _ => null,
    };
  }

  int? _intConfig(dynamic value) => value is int ? value : int.tryParse('$value');
}

class _FormulaParser {
  _FormulaParser(
    this.source, {
    required this.propertyValue,
  });

  final String source;
  final num? Function(int propertyId) propertyValue;
  int index = 0;

  num? parse() {
    final value = _expression();
    _skipWhitespace();
    if (index != source.length) {
      throw FormatException('Unexpected token at position $index.', source);
    }
    return value;
  }

  num? _expression() {
    var value = _term();
    while (true) {
      _skipWhitespace();
      if (_consume('+')) {
        value = _binary(value, _term(), (a, b) => a + b);
      } else if (_consume('-')) {
        value = _binary(value, _term(), (a, b) => a - b);
      } else {
        return value;
      }
    }
  }

  num? _term() {
    var value = _factor();
    while (true) {
      _skipWhitespace();
      if (_consume('*')) {
        value = _binary(value, _factor(), (a, b) => a * b);
      } else if (_consume('/')) {
        final right = _factor();
        if (right == 0) return null;
        value = _binary(value, right, (a, b) => a / b);
      } else {
        return value;
      }
    }
  }

  num? _factor() {
    _skipWhitespace();
    if (_consume('-')) {
      final value = _factor();
      return value == null ? null : -value;
    }
    if (_consume('(')) {
      final value = _expression();
      _skipWhitespace();
      if (!_consume(')')) {
        throw FormatException('Missing closing parenthesis.', source);
      }
      return value;
    }
    if (_consume('{')) {
      final start = index;
      while (index < source.length && source[index] != '}') {
        index++;
      }
      if (index >= source.length) {
        throw FormatException('Missing closing brace.', source);
      }
      final propertyId = int.tryParse(source.substring(start, index).trim());
      index++;
      if (propertyId == null) {
        throw FormatException('Property reference must be numeric.', source);
      }
      return propertyValue(propertyId);
    }
    return _number();
  }

  num _number() {
    _skipWhitespace();
    final start = index;
    var seenDot = false;
    while (index < source.length) {
      final char = source[index];
      if (char == '.') {
        if (seenDot) break;
        seenDot = true;
        index++;
        continue;
      }
      if (!_isDigit(char)) break;
      index++;
    }
    if (start == index) {
      throw FormatException('Expected number at position $index.', source);
    }
    return num.parse(source.substring(start, index));
  }

  num? _binary(
    num? left,
    num? right,
    num Function(num, num) operation,
  ) {
    if (left == null || right == null) return null;
    return operation(left, right);
  }

  void _skipWhitespace() {
    while (index < source.length && source[index].trim().isEmpty) {
      index++;
    }
  }

  bool _consume(String token) {
    if (index < source.length && source[index] == token) {
      index++;
      return true;
    }
    return false;
  }

  bool _isDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
