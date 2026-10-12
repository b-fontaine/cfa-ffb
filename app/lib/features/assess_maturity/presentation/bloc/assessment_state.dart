part of 'assessment_bloc.dart';

enum AssessmentStatus { idle, saving, saved, failure }

@freezed
abstract class AssessmentState with _$AssessmentState {
  const factory AssessmentState({
    @Default(AssessmentStatus.idle) AssessmentStatus status,

    /// Dernier bilan enregistré, avec l'aide à la décision.
    AssessmentOutcome? outcome,
    Failure? failure,
  }) = _AssessmentState;
}
