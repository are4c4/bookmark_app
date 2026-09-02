import '../domain/object_type_defaults.dart';
import 'database_view_store.dart';

/// Typed adapter for the Object opening mode stored in View settings.
///
/// This keeps the adopted resolution order explicit:
/// View override > Database override > ObjectType default > app fallback.
class DatabaseViewOpenModeService {
  const DatabaseViewOpenModeService(this.store);

  static const settingsKey = 'openMode';

  final DatabaseViewStore store;

  ObjectOpenMode? overrideFor(DatabaseViewConfig view) {
    final raw = view.settings[settingsKey];
    if (raw == null) return null;
    final name = '$raw';
    for (final mode in ObjectOpenMode.values) {
      if (mode.name == name) return mode;
    }
    throw FormatException('Unknown View Object open mode: $name');
  }

  ObjectOpenMode resolve({
    required DatabaseViewConfig view,
    ObjectOpenMode? databaseOverride,
    ObjectOpenMode? objectTypeDefault,
    ObjectOpenMode appFallback = ObjectOpenMode.sidePeek,
  }) {
    return overrideFor(view) ??
        databaseOverride ??
        objectTypeDefault ??
        appFallback;
  }

  Future<DatabaseViewConfig> setOverride({
    required DatabaseViewConfig view,
    ObjectOpenMode? mode,
  }) async {
    final canonical = await _requireCurrent(view);
    final settings = Map<String, dynamic>.from(canonical.settings);
    if (mode == null) {
      settings.remove(settingsKey);
    } else {
      settings[settingsKey] = mode.name;
    }
    final next = canonical.copyWith(settings: settings);
    await store.updateView(next);
    return _find(
      workspaceId: canonical.workspaceId,
      databaseKey: canonical.databaseKey,
      id: canonical.id,
    );
  }

  Future<DatabaseViewConfig> _requireCurrent(DatabaseViewConfig view) async {
    final views = await store.listViews(
      workspaceId: view.workspaceId,
      databaseKey: view.databaseKey,
    );
    for (final candidate in views) {
      if (candidate.id == view.id) return candidate;
    }
    throw ArgumentError.value(
      view.id,
      'view',
      'View does not belong to the supplied workspace/Database scope.',
    );
  }

  Future<DatabaseViewConfig> _find({
    required int workspaceId,
    required String databaseKey,
    required int id,
  }) async {
    final views = await store.listViews(
      workspaceId: workspaceId,
      databaseKey: databaseKey,
    );
    return views.firstWhere((view) => view.id == id);
  }
}
