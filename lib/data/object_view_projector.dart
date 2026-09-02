import '../domain/object_group.dart';
import '../domain/object_model.dart';
import 'database_view_group_adapter.dart';
import 'database_view_query_adapter.dart';
import 'database_view_store.dart';
import 'object_group_engine.dart';
import 'object_query_engine.dart';

typedef ObjectViewValueResolver = dynamic Function(
  AppObject object,
  int? propertyId,
);

class ObjectViewProjection {
  const ObjectViewProjection({
    required this.objects,
    required this.groups,
    required this.queryState,
    required this.groupRule,
  });

  final List<AppObject> objects;
  final List<ObjectGroupBucket<AppObject>> groups;
  final DatabaseViewQueryState queryState;
  final ObjectGroupRule? groupRule;

  bool get isGrouped => groupRule != null;
}

class ObjectViewProjector {
  const ObjectViewProjector({
    this.queryAdapter = const DatabaseViewQueryAdapter(),
    this.groupAdapter = const DatabaseViewGroupAdapter(),
    this.queryEngine = const ObjectQueryEngine(),
    this.groupEngine = const ObjectGroupEngine(),
  });

  final DatabaseViewQueryAdapter queryAdapter;
  final DatabaseViewGroupAdapter groupAdapter;
  final ObjectQueryEngine queryEngine;
  final ObjectGroupEngine groupEngine;

  ObjectViewProjection project({
    required Iterable<AppObject> objects,
    required DatabaseViewConfig view,
    ObjectViewValueResolver? valueResolver,
  }) {
    final query = queryAdapter.decode(view);
    final groupRule = groupAdapter.decode(view);
    final resolve = valueResolver ?? _defaultResolver;

    var result = objects.toList(growable: false);
    final search = query.searchQuery.trim().toLowerCase();
    if (search.isNotEmpty) {
      result = result
          .where((object) => _matchesSearch(object, search, resolve))
          .toList(growable: false);
    }

    result = queryEngine.apply(
      objects: result,
      filters: query.filters,
      sorts: query.sorts,
      valueResolver: resolve,
    );

    final groups = groupRule == null
        ? const <ObjectGroupBucket<AppObject>>[]
        : groupEngine.group(
            objects: result,
            rule: groupRule,
            valueResolver: (object, propertyId) => resolve(object, propertyId),
          );

    return ObjectViewProjection(
      objects: result,
      groups: groups,
      queryState: query,
      groupRule: groupRule,
    );
  }

  dynamic _defaultResolver(AppObject object, int? propertyId) =>
      propertyId == null ? object.title : object.values[propertyId];

  bool _matchesSearch(
    AppObject object,
    String search,
    ObjectViewValueResolver resolve,
  ) {
    if (object.title.toLowerCase().contains(search)) return true;
    for (final propertyId in object.values.keys) {
      if (_searchable(resolve(object, propertyId)).contains(search)) return true;
    }
    return false;
  }

  String _searchable(dynamic value) {
    if (value == null) return '';
    if (value is Map && value['objectIds'] is Iterable) {
      return (value['objectIds'] as Iterable).join(' ').toLowerCase();
    }
    if (value is Iterable && value is! String) {
      return value.join(' ').toLowerCase();
    }
    return '$value'.toLowerCase();
  }
}
