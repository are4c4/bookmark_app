import '../domain/object_model.dart';
import 'daily_note_service.dart';

/// Object-owned navigation helper for time-based Daily Note workflows.
///
/// Daily Notes remain ordinary Objects. This service only derives adjacent
/// local calendar dates and delegates opening/creation to [DailyNoteService].
class DailyNoteNavigationService {
  const DailyNoteNavigationService(this.dailyNotes);

  final DailyNoteService dailyNotes;

  Future<AppObject> openToday({required int workspaceId, DateTime? now}) {
    return dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: (now ?? DateTime.now()).toLocal(),
    );
  }

  Future<AppObject> openPrevious({
    required int workspaceId,
    required DateTime currentDate,
  }) {
    return dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: _calendarDate(currentDate).subtract(const Duration(days: 1)),
    );
  }

  Future<AppObject> openNext({
    required int workspaceId,
    required DateTime currentDate,
  }) {
    return dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: _calendarDate(currentDate).add(const Duration(days: 1)),
    );
  }

  DateTime _calendarDate(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
