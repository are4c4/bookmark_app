import '../domain/object_detail_content.dart';
import 'daily_note_navigation_service.dart';
import 'object_detail_content_loader.dart';

/// Composes Daily Note calendar navigation with the shared Object detail model.
///
/// This keeps previous/today/next UI surfaces on the same Object detail payload
/// used by every other Object presentation instead of introducing note-specific
/// state or editing behavior.
class DailyNoteDetailNavigationService {
  const DailyNoteDetailNavigationService({
    required this.navigation,
    required this.detailLoader,
  });

  final DailyNoteNavigationService navigation;
  final ObjectDetailContentLoader detailLoader;

  Future<ObjectDetailContent> openToday({
    required int workspaceId,
    DateTime? now,
  }) async {
    final object = await navigation.openToday(
      workspaceId: workspaceId,
      now: now,
    );
    return _load(object.objectTypeId, object.id);
  }

  Future<ObjectDetailContent> openPrevious({
    required int workspaceId,
    required DateTime currentDate,
  }) async {
    final object = await navigation.openPrevious(
      workspaceId: workspaceId,
      currentDate: currentDate,
    );
    return _load(object.objectTypeId, object.id);
  }

  Future<ObjectDetailContent> openNext({
    required int workspaceId,
    required DateTime currentDate,
  }) async {
    final object = await navigation.openNext(
      workspaceId: workspaceId,
      currentDate: currentDate,
    );
    return _load(object.objectTypeId, object.id);
  }

  Future<ObjectDetailContent> _load(int objectTypeId, int objectId) async {
    final content = await detailLoader.load(
      objectTypeId: objectTypeId,
      objectId: objectId,
    );
    if (content == null) {
      throw StateError('Daily Note disappeared after calendar navigation.');
    }
    return content;
  }
}
