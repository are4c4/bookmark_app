import '../domain/object_detail_content.dart';
import 'daily_note_service.dart';
import 'object_detail_content_loader.dart';

/// Opens/creates a Daily Note and immediately resolves the same shared detail
/// payload used by every other Object surface.
///
/// This keeps Daily Note navigation from creating a special editor/data silo.
class DailyNoteDetailService {
  DailyNoteDetailService({
    required this.dailyNotes,
    required this.detailLoader,
  });

  final DailyNoteService dailyNotes;
  final ObjectDetailContentLoader detailLoader;

  Future<ObjectDetailContent> open({
    required int workspaceId,
    required DateTime localDate,
  }) async {
    final daily = await dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      localDate: localDate,
    );
    final content = await detailLoader.load(
      objectTypeId: daily.objectType.id,
      objectId: daily.object.id,
    );
    if (content == null) {
      throw StateError('Daily Note disappeared after open-or-create.');
    }
    return content;
  }
}
