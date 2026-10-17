import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/student_showcase/domain/list_linked_students.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Où en est le chargement des élèves liés au compte.
enum LinkedStudentsStatus { loading, ready, failed }

/// État de « Mes enfants » / « Ma progression ».
class LinkedStudentsState {
  const LinkedStudentsState({
    this.status = LinkedStudentsStatus.loading,
    this.students = const [],
    this.failure,
  });

  final LinkedStudentsStatus status;
  final List<Student> students;
  final Failure? failure;
}

/// Les élèves liés au compte, pour l'accueil d'un parent ou d'un élève.
@injectable
class LinkedStudentsCubit extends Cubit<LinkedStudentsState> {
  LinkedStudentsCubit(this._list) : super(const LinkedStudentsState());

  final ListLinkedStudents _list;

  Future<void> load() async {
    final result = await _list();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => LinkedStudentsState(
        status: LinkedStudentsStatus.ready,
        students: value,
      ),
      Err(:final failure) => LinkedStudentsState(
        status: LinkedStudentsStatus.failed,
        failure: failure,
      ),
    });
  }
}
