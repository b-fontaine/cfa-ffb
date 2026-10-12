part of 'student_recall_bloc.dart';

@freezed
sealed class StudentRecallEvent with _$StudentRecallEvent {
  const factory StudentRecallEvent.started({required StudentId studentId}) =
      StudentRecallStarted;
}
