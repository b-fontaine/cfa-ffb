part of 'student_erasure_bloc.dart';

enum StudentErasureStatus { idle, working, erased, failure }

@freezed
abstract class StudentErasureState with _$StudentErasureState {
  const factory StudentErasureState({
    @Default(StudentErasureStatus.idle) StudentErasureStatus status,
    Failure? failure,
  }) = _StudentErasureState;
}
