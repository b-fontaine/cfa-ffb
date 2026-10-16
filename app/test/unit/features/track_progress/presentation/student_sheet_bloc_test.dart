import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/track_progress/domain/get_student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/sheet_header.dart';
import 'package:billard_cfa/features/track_progress/domain/student_report.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/shared/lib/attendance.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixtures.dart';

class _MockGetStudentSheet extends Mock implements GetStudentSheet;

void main() {
  late _MockGetStudentSheet getSheet;
  const id = StudentId('s1');
  final sheet = StudentSheet(
    student: Student.enroll(
      id: id,
      firstName: 'Léa',
      audience: Audience.children,
      since: DateTime(2026, 9),
    ),
    report: const StudentReport(
      studentId: id,
      validatedCount: 0,
      exerciseCount: 9,
      blocks: [],
      activeAlerts: [],
      attendance: Attendance(attended: 0, total: 0),
    ),
    catalogue: buildCatalogue(),
    series: const [],
    path: const [],
    header: const SheetHeader(
      current: null,
      currentPassed: 0,
      passesRequired: 5,
      next: null,
      finishedTechniques: 0,
      techniqueCount: 3,
      validatedExercises: 0,
      exerciseCount: 9,
      toStart: true,
      levelCompleted: false,
      alert: null,
      acknowledged: [],
    ),
    nextExercise: null,
    passesRequired: 5,
    assessmentCount: 0,
    latestAssessment: null,
    readinessHint: null,
  );

  setUp(() => getSheet = _MockGetStudentSheet());

  blocTest<StudentSheetBloc, StudentSheetState>(
    'loads the sheet of the student',
    build: () {
      when(() => getSheet(id)).thenAnswer((_) async => Ok(sheet));
      return StudentSheetBloc(getSheet);
    },
    act: (bloc) => bloc.add(const StudentSheetEvent.started(studentId: id)),
    expect: () => [
      const StudentSheetState(studentId: id),
      StudentSheetState(
        status: StudentSheetStatus.ready,
        studentId: id,
        sheet: sheet,
      ),
    ],
  );

  blocTest<StudentSheetBloc, StudentSheetState>(
    'reports an unknown student',
    build: () {
      when(() => getSheet(id))
          .thenAnswer((_) async => const Err(NotFound('student', 's1')));
      return StudentSheetBloc(getSheet);
    },
    act: (bloc) => bloc.add(const StudentSheetEvent.started(studentId: id)),
    expect: () => [
      const StudentSheetState(studentId: id),
      const StudentSheetState(
        status: StudentSheetStatus.failure,
        studentId: id,
        failure: NotFound('student', 's1'),
      ),
    ],
  );

  blocTest<StudentSheetBloc, StudentSheetState>(
    'reloads the same student on refresh',
    build: () {
      when(() => getSheet(id)).thenAnswer((_) async => Ok(sheet));
      return StudentSheetBloc(getSheet);
    },
    seed: () => const StudentSheetState(studentId: id),
    act: (bloc) => bloc.add(const StudentSheetEvent.refreshed()),
    expect: () => [
      StudentSheetState(
        status: StudentSheetStatus.ready,
        studentId: id,
        sheet: sheet,
      ),
    ],
    verify: (_) => verify(() => getSheet(id)).called(1),
  );

  blocTest<StudentSheetBloc, StudentSheetState>(
    'ignores a refresh before any student was opened',
    build: () => StudentSheetBloc(getSheet),
    act: (bloc) => bloc.add(const StudentSheetEvent.refreshed()),
    expect: () => <StudentSheetState>[],
    verify: (_) => verifyNever(() => getSheet(any())),
  );
}
