import 'package:billard_cfa/features/assess_maturity/domain/assessment_outcome.dart';
import 'package:billard_cfa/features/assess_maturity/domain/record_assessment.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'assessment_bloc.freezed.dart';
part 'assessment_event.dart';
part 'assessment_state.dart';

/// Enregistrement d'un bilan de maturité (aide à la décision uniquement).
@injectable
class AssessmentBloc extends Bloc<AssessmentEvent, AssessmentState> {
  AssessmentBloc(this._record, this._clock) : super(const AssessmentState()) {
    on<AssessmentSubmitted>(_onSubmitted);
  }

  final RecordAssessment _record;
  final Clock _clock;

  Future<void> _onSubmitted(
    AssessmentSubmitted event,
    Emitter<AssessmentState> emit,
  ) async {
    emit(const AssessmentState(status: AssessmentStatus.saving));
    final today = _clock.today();
    final comment = event.comment?.trim();
    final result = await _record(
      studentId: event.studentId,
      date: today,
      today: today,
      concentration: event.concentration,
      endurance: event.endurance,
      frustration: event.frustration,
      comment: comment == null || comment.isEmpty ? null : comment,
    );
    switch (result) {
      case Ok(:final value):
        emit(AssessmentState(status: AssessmentStatus.saved, outcome: value));
      case Err(:final failure):
        emit(
          AssessmentState(status: AssessmentStatus.failure, failure: failure),
        );
    }
  }
}
