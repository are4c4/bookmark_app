import 'database_view_store.dart';

class DatabaseViewTableColumnWidthsAdapter {
  const DatabaseViewTableColumnWidthsAdapter();

  static const settingsKey = 'tableColumnWidths';

  Map<String, dynamic> decode(DatabaseViewConfig view) {
    final raw = view.settings[settingsKey];
    if (raw is! Map) return const <String, dynamic>{};

    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is String) result[key] = entry.value;
    }
    return result;
  }

  DatabaseViewConfig withWidth(
    DatabaseViewConfig view, {
    required String key,
    required double width,
  }) {
    final widths = <String, dynamic>{...decode(view), key: width};
    return view.copyWith(
      settings: <String, dynamic>{...view.settings, settingsKey: widths},
    );
  }
}
