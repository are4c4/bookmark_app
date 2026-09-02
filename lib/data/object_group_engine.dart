import '../domain/object_group.dart';
import '../domain/object_model.dart';

typedef ObjectGroupValueResolver = dynamic Function(
  AppObject object,
  int propertyId,
);

class ObjectGroupEngine {
  const ObjectGroupEngine();

  List<ObjectGroupBucket<AppObject>> group({
    required Iterable<AppObject> objects,
    required ObjectGroupRule rule,
    ObjectGroupValueResolver? valueResolver,
    String emptyLabel = '未設定',
  }) {
    final resolve = valueResolver ??
        (AppObject object, int propertyId) => object.values[propertyId];
    final buckets = <String, _MutableBucket>{};

    for (final object in objects) {
      final values = _groupValues(resolve(object, rule.propertyId));
      if (values.isEmpty) {
        if (!rule.includeEmpty) continue;
        final bucket = buckets.putIfAbsent(
          '__empty__',
          () => _MutableBucket(
            label: emptyLabel,
            value: null,
            isEmptyGroup: true,
          ),
        );
        bucket.items.add(object);
        continue;
      }
      for (final value in values) {
        final key = _key(value);
        final bucket = buckets.putIfAbsent(
          key,
          () => _MutableBucket(
            label: _label(value),
            value: value,
            isEmptyGroup: false,
          ),
        );
        bucket.items.add(object);
      }
    }

    final result = buckets.entries
        .map(
          (entry) => ObjectGroupBucket<AppObject>(
            key: entry.key,
            label: entry.value.label,
            value: entry.value.value,
            items: List.unmodifiable(entry.value.items),
            isEmptyGroup: entry.value.isEmptyGroup,
          ),
        )
        .toList(growable: false);
    result.sort((a, b) {
      if (a.isEmptyGroup != b.isEmptyGroup) return a.isEmptyGroup ? 1 : -1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return result;
  }

  List<dynamic> _groupValues(dynamic value) {
    if (_isEmpty(value)) return const [];
    if (value is Map && value['objectIds'] is Iterable) {
      return (value['objectIds'] as Iterable).toList(growable: false);
    }
    if (value is Iterable && value is! String) {
      return value.where((item) => !_isEmpty(item)).toList(growable: false);
    }
    return <dynamic>[value];
  }

  bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  String _key(dynamic value) {
    if (value is bool) return 'bool:$value';
    if (value is num) return 'num:$value';
    return 'value:${value.toString().toLowerCase()}';
  }

  String _label(dynamic value) {
    if (value is bool) return value ? 'オン' : 'オフ';
    return '$value';
  }
}

class _MutableBucket {
  _MutableBucket({
    required this.label,
    required this.value,
    required this.isEmptyGroup,
  });

  final String label;
  final dynamic value;
  final bool isEmptyGroup;
  final List<AppObject> items = [];
}
