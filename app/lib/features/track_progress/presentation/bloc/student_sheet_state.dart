part of 'student_sheet_bloc.dart';

enum StudentSheetStatus { loading, ready, failure }

@freezed
abstract class StudentSheetState with _$StudentSheetState {
  const factory StudentSheetState({
    @Default(StudentSheetStatus.loading) StudentSheetStatus status,
    StudentId? studentId,
    StudentSheet? sheet,
    Failure? failure,
  }) = _StudentSheetState;
}
