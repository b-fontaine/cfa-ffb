import 'package:billard_cfa/features/suggest_session/domain/recall_advice.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_recall.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'student_recall_bloc.freezed.dart';
part 'student_recall_event.dart';
part 'student_recall_state.dart';

/// La notion à rappeler à un élève (affichée sur sa fiche).
@injectable
class StudentRecallBloc extends Bloc<StudentRecallEvent, StudentRecallState> {
  StudentRecallBloc(this._suggest) : super(const StudentRecallState()) {
    on<StudentRecallStarted>(_onStarted);
  }

  final SuggestRecall _suggest;

  Future<void> _onStarted(
    StudentRecallStarted event,
    Emitter<StudentRecallState> emit,
  ) async {
    emit(const StudentRecallState());
    switch (await _suggest(event.studentId)) {
      case Ok(:final value):
        emit(StudentRecallState(status: RecallStatus.ready, advice: value));
      case Err(:final failure):
        emit(
          StudentRecallState(status: RecallStatus.failure, failure: failure),
        );
    }
  }
}
