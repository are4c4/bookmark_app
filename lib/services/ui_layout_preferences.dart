import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only presentation preferences for desktop layout chrome.
///
/// These values are intentionally separate from Object/Database/Vault content
/// persistence. Sidebar state is app-wide chrome preference, while detail pane
/// keys describe presentation identity rather than persisted content identity.
class UiLayoutPreferences {
  const UiLayoutPreferences();

  static const _sidebarCollapsedKey = 'ui.layout.sidebarCollapsed.v1';
  static const _detailPaneWidthPrefix = 'ui.layout.detailPaneWidth.v1';

  Future<bool?> loadSidebarCollapsed() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.get(_sidebarCollapsedKey);
      return value is bool ? value : null;
    } catch (_, stackTrace) {
      _debugFailure('sidebar state load', stackTrace);
      return null;
    }
  }

  Future<void> saveSidebarCollapsed(bool collapsed) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_sidebarCollapsedKey, collapsed);
    } catch (_, stackTrace) {
      _debugFailure('sidebar state save', stackTrace);
    }
  }

  Future<double?> loadDetailPaneWidth(String storageKey) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.get(_detailPaneWidthKey(storageKey));
      if (value is num) {
        final width = value.toDouble();
        if (width.isFinite) return width;
      }
    } catch (_, stackTrace) {
      _debugFailure('detail pane width load', stackTrace);
    }
    return null;
  }

  Future<void> saveDetailPaneWidth(String storageKey, double width) async {
    if (!width.isFinite) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_detailPaneWidthKey(storageKey), width);
    } catch (_, stackTrace) {
      _debugFailure('detail pane width save', stackTrace);
    }
  }

  String _detailPaneWidthKey(String storageKey) {
    final presentationKey = _detailPanePresentationKey(storageKey);
    return '$_detailPaneWidthPrefix.${Uri.encodeComponent(presentationKey)}';
  }

  String _detailPanePresentationKey(String storageKey) {
    if (RegExp(r'^generic-db-\d+-detail$').hasMatch(storageKey)) {
      return 'generic-database-detail';
    }
    return storageKey;
  }

  void _debugFailure(String operation, StackTrace stackTrace) {
    assert(() {
      developer.log(
        'UiLayoutPreferences: $operation failed; using layout defaults.',
        name: 'bookmark_app.ui_layout_preferences',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }
}
