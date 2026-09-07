import '../domain/object_group.dart';
import 'database_view_store.dart';

class DatabaseViewGroupAdapter {
  const DatabaseViewGroupAdapter();

  static const groupSettingsKey = 'groupRule';

  ObjectGroupRule? decode(DatabaseViewConfig view) =>
      ObjectGroupRule.fromJson(view.settings[groupSettingsKey]);

  Map<String, dynamic> encodeSettings(
    Map<String, dynamic> current, {
    required ObjectGroupRule? group,
  }) {
    final settings = <String, dynamic>{...current};
    if (group == null) {
      settings.remove(groupSettingsKey);
    } else {
      settings[groupSettingsKey] = group.toJson();
    }
    return settings;
  }

  DatabaseViewConfig encode(
    DatabaseViewConfig view, {
    required ObjectGroupRule? group,
  }) =>
      view.copyWith(
        settings: encodeSettings(view.settings, group: group),
      );

  DatabaseViewConfig clear(DatabaseViewConfig view) =>
      encode(view, group: null);
}
