part of 'student_erasure_bloc.dart';

@freezed
sealed class StudentErasureEvent with _$StudentErasureEvent {
  const factory StudentErasureEvent.requested({required StudentId studentId}) =
      StudentErasureRequested;
}
