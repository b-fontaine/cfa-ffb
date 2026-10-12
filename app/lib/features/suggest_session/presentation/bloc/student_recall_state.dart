part of 'student_recall_bloc.dart';

enum RecallStatus { loading, ready, failure }

@freezed
abstract class StudentRecallState with _$StudentRecallState {
  const factory StudentRecallState({
    @Default(RecallStatus.loading) RecallStatus status,

    /// Notion à rappeler ; `null` quand rien ne le justifie.
    RecallAdvice? advice,
    Failure? failure,
  }) = _StudentRecallState;
}
