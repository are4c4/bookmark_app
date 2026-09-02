import '../domain/object_query.dart';
import 'database_view_store.dart';

class DatabaseViewQueryState {
  const DatabaseViewQueryState({
    this.searchQuery = '',
    this.filters = const <ObjectFilterRule>[],
    this.sorts = const <ObjectSortRule>[],
  });

  final String searchQuery;
  final List<ObjectFilterRule> filters;
  final List<ObjectSortRule> sorts;
}

class DatabaseViewQueryAdapter {
  const DatabaseViewQueryAdapter();

  static const _rulesKey = 'propertyRules';

  DatabaseViewQueryState decode(DatabaseViewConfig view) {
    final rawFilters = view.filters[_rulesKey];
    final filters = <ObjectFilterRule>[];
    if (rawFilters is List) {
      for (final raw in rawFilters) {
        final rule = ObjectFilterRule.fromJson(raw);
        if (rule != null) filters.add(rule);
      }
    }

    final sorts = <ObjectSortRule>[];
    for (final raw in view.sorts) {
      final rule = ObjectSortRule.fromJson(raw);
      if (rule != null) sorts.add(rule);
    }

    return DatabaseViewQueryState(
      searchQuery: '${view.filters['query'] ?? ''}',
      filters: filters,
      sorts: sorts,
    );
  }

  DatabaseViewConfig encode(
    DatabaseViewConfig view, {
    String? searchQuery,
    List<ObjectFilterRule>? filters,
    List<ObjectSortRule>? sorts,
  }) {
    final current = decode(view);
    final nextFilters = filters ?? current.filters;
    final nextSorts = sorts ?? current.sorts;
    return view.copyWith(
      filters: <String, dynamic>{
        ...view.filters,
        'query': searchQuery ?? current.searchQuery,
        _rulesKey: nextFilters.map((rule) => rule.toJson()).toList(),
      },
      sorts: nextSorts.map((rule) => rule.toJson()).toList(),
    );
  }

  DatabaseViewConfig clearFilters(DatabaseViewConfig view) =>
      encode(view, filters: const <ObjectFilterRule>[]);

  DatabaseViewConfig clearSorts(DatabaseViewConfig view) =>
      encode(view, sorts: const <ObjectSortRule>[]);
}
