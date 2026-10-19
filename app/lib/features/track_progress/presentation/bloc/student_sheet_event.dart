part of 'student_sheet_bloc.dart';

@freezed
sealed class StudentSheetEvent with _$StudentSheetEvent {
  const factory StudentSheetEvent.started({required StudentId studentId}) =
      StudentSheetStarted;

  const factory StudentSheetEvent.refreshed() = StudentSheetRefreshed;

  /// Les données de la fiche ont changé (cet appareil ou un autre) : relecture
  /// en place. `done` est complété à la fin de la relecture (voir
  /// `LiveReload` : jamais deux relectures en parallèle).
  const factory StudentSheetEvent.changed({required Completer<void> done}) =
      StudentSheetChanged;
}
