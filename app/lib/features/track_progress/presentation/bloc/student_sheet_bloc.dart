import 'package:billard_cfa/features/track_progress/domain/get_student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'student_sheet_bloc.freezed.dart';
part 'student_sheet_event.dart';
part 'student_sheet_state.dart';

/// La fiche d'un élève : progression par bloc, courbes, exercice suivant.
@injectable
class StudentSheetBloc extends Bloc<StudentSheetEvent, StudentSheetState> {
  StudentSheetBloc(this._getSheet) : super(const StudentSheetState()) {
    on<StudentSheetStarted>(_onStarted);
    on<StudentSheetRefreshed>(_onRefreshed);
  }

  final GetStudentSheet _getSheet;

  Future<void> _onStarted(
    StudentSheetStarted event,
    Emitter<StudentSheetState> emit,
  ) async {
    emit(StudentSheetState(studentId: event.studentId));
    await _load(event.studentId, emit);
  }

  Future<void> _onRefreshed(
    StudentSheetRefreshed event,
    Emitter<StudentSheetState> emit,
  ) async {
    final id = state.studentId;
    if (id != null) await _load(id, emit);
  }

  Future<void> _load(StudentId id, Emitter<StudentSheetState> emit) async {
    switch (await _getSheet(id)) {
      case Ok(:final value):
        emit(
          StudentSheetState(
            status: StudentSheetStatus.ready,
            studentId: id,
            sheet: value,
          ),
        );
      case Err(:final failure):
        emit(
          StudentSheetState(
            status: StudentSheetStatus.failure,
            studentId: id,
            failure: failure,
          ),
        );
    }
  }
}
