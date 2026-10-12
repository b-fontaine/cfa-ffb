part of 'student_sheet_bloc.dart';

@freezed
sealed class StudentSheetEvent with _$StudentSheetEvent {
  const factory StudentSheetEvent.started({required StudentId studentId}) =
      StudentSheetStarted;

  const factory StudentSheetEvent.refreshed() = StudentSheetRefreshed;
}
