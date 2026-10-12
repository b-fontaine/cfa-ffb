import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_students/domain/enroll_student.dart';
import 'package:billard_cfa/features/manage_students/domain/get_student.dart';
import 'package:billard_cfa/features/manage_students/domain/rename_student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'student_form_bloc.freezed.dart';
part 'student_form_event.dart';
part 'student_form_state.dart';

/// Ajout (prénom + public) ou correction du prénom d'un élève.
@injectable
class StudentFormBloc extends Bloc<StudentFormEvent, StudentFormState> {
  StudentFormBloc(this._getStudent, this._enroll, this._rename, this._clock)
    : super(const StudentFormState()) {
    on<StudentFormStarted>(_onStarted);
    on<StudentFormSubmitted>(_onSubmitted);
  }

  final GetStudent _getStudent;
  final EnrollStudent _enroll;
  final RenameStudent _rename;
  final Clock _clock;

  Future<void> _onStarted(
    StudentFormStarted event,
    Emitter<StudentFormState> emit,
  ) async {
    final id = event.studentId;
    if (id == null) {
      emit(const StudentFormState(status: StudentFormStatus.ready));
      return;
    }
    emit(const StudentFormState());
    switch (await _getStudent(id)) {
      case Ok(:final value):
        emit(StudentFormState(status: StudentFormStatus.ready, student: value));
      case Err(:final failure):
        emit(
          StudentFormState(status: StudentFormStatus.failure, failure: failure),
        );
    }
  }

  Future<void> _onSubmitted(
    StudentFormSubmitted event,
    Emitter<StudentFormState> emit,
  ) async {
    final editing = state.student;
    emit(state.copyWith(status: StudentFormStatus.saving, failure: null));
    final Result<Student> result;
    if (editing == null) {
      result = switch (await _enroll(
        firstName: event.firstName,
        audience: event.audience,
        today: _clock.today(),
        groupName: event.groupName,
      )) {
        Ok(:final value) => Ok(value.student),
        Err(:final failure) => Err(failure),
      };
    } else {
      result = await _rename(studentId: editing.id, firstName: event.firstName);
    }
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: StudentFormStatus.saved, saved: value));
      case Err(:final failure):
        emit(state.copyWith(status: StudentFormStatus.ready, failure: failure));
    }
  }
}
