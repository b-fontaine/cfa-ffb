import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'student_erasure_bloc.freezed.dart';
part 'student_erasure_event.dart';
part 'student_erasure_state.dart';

/// Effacement physique d'un élève (la confirmation est demandée par l'écran).
@injectable
class StudentErasureBloc
    extends Bloc<StudentErasureEvent, StudentErasureState> {
  StudentErasureBloc(this._erase) : super(const StudentErasureState()) {
    on<StudentErasureRequested>(_onRequested);
  }

  final EraseStudent _erase;

  Future<void> _onRequested(
    StudentErasureRequested event,
    Emitter<StudentErasureState> emit,
  ) async {
    emit(const StudentErasureState(status: StudentErasureStatus.working));
    switch (await _erase(event.studentId)) {
      case Ok():
        emit(const StudentErasureState(status: StudentErasureStatus.erased));
      case Err(:final failure):
        emit(
          StudentErasureState(
            status: StudentErasureStatus.failure,
            failure: failure,
          ),
        );
    }
  }
}
