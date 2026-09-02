import '../domain/object_group.dart';
import 'database_view_store.dart';

class DatabaseViewGroupAdapter {
  const DatabaseViewGroupAdapter();

  static const _groupKey = 'groupRule';

  ObjectGroupRule? decode(DatabaseViewConfig view) =>
      ObjectGroupRule.fromJson(view.settings[_groupKey]);

  DatabaseViewConfig encode(
    DatabaseViewConfig view, {
    required ObjectGroupRule? group,
  }) {
    final settings = <String, dynamic>{...view.settings};
    if (group == null) {
      settings.remove(_groupKey);
    } else {
      settings[_groupKey] = group.toJson();
    }
    return view.copyWith(settings: settings);
  }

  DatabaseViewConfig clear(DatabaseViewConfig view) =>
      encode(view, group: null);
}
