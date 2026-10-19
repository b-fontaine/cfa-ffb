import 'dart:async';

import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/track_progress/domain/get_student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/sheet_header.dart';
import 'package:billard_cfa/features/track_progress/domain/student_report.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_student_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/shared/lib/attendance.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/stream_log.dart';

class _MockGetStudentSheet extends Mock implements GetStudentSheet;

class _MockWatch extends Mock implements WatchStudentSheet;

void main() {
  late _MockGetStudentSheet getSheet;
  late _MockWatch watch;
  late StreamController<void> changes;
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

  setUp(() {
    getSheet = _MockGetStudentSheet();
    watch = _MockWatch();
    changes = StreamController<void>.broadcast();
    when(() => watch(any())).thenAnswer((_) => changes.stream);
  });

  tearDown(() => changes.close());

  blocTest<StudentSheetBloc, StudentSheetState>(
    'loads the sheet of the student',
    build: () {
      when(() => getSheet(id)).thenAnswer((_) async => Ok(sheet));
      return StudentSheetBloc(getSheet, watch);
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
      return StudentSheetBloc(getSheet, watch);
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
      return StudentSheetBloc(getSheet, watch);
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
    build: () => StudentSheetBloc(getSheet, watch),
    act: (bloc) => bloc.add(const StudentSheetEvent.refreshed()),
    expect: () => <StudentSheetState>[],
    verify: (_) => verifyNever(() => getSheet(any())),
  );

  group('live updates', () {
    final other = StudentSheet(
      student: sheet.student,
      report: sheet.report,
      catalogue: sheet.catalogue,
      series: sheet.series,
      path: sheet.path,
      header: sheet.header,
      nextExercise: null,
      passesRequired: 5,
      assessmentCount: 1,
      latestAssessment: null,
      readinessHint: null,
    );

    test('watches the changes of the student once started', () async {
      when(() => getSheet(id)).thenAnswer((_) async => Ok(sheet));
      final bloc = StudentSheetBloc(getSheet, watch)
        ..add(const StudentSheetEvent.started(studentId: id));
      await pumpEventQueue();

      verify(() => watch(id)).called(1);
      expect(changes.hasListener, isTrue);
      await bloc.close();
    });

    test('reloads in place, without a loading state, on a change', () async {
      var calls = 0;
      when(() => getSheet(id))
          .thenAnswer((_) async => Ok(calls++ == 0 ? sheet : other));
      final bloc = StudentSheetBloc(getSheet, watch);
      final log = StreamLog(bloc.stream);
      bloc.add(const StudentSheetEvent.started(studentId: id));
      await log.settle();

      changes.add(null);
      await log.settle();

      expect(
        [for (final s in log.values) s.status],
        [
          StudentSheetStatus.loading,
          StudentSheetStatus.ready,
          StudentSheetStatus.ready,
        ],
      );
      expect(log.last.sheet, other);
      await log.cancel();
      await bloc.close();
    });

    test('a burst of changes during a reload costs one more reload', () async {
      final gate = Completer<void>();
      var calls = 0;
      when(() => getSheet(id)).thenAnswer((_) async {
        if (calls++ == 1) await gate.future;
        return Ok(sheet);
      });
      final bloc = StudentSheetBloc(getSheet, watch)
        ..add(const StudentSheetEvent.started(studentId: id));
      await pumpEventQueue();
      expect(calls, 1);

      changes.add(null);
      await pumpEventQueue();
      changes
        ..add(null)
        ..add(null);
      await pumpEventQueue();
      expect(calls, 2);

      gate.complete();
      await pumpEventQueue();

      expect(calls, 3);
      await bloc.close();
    });

    test('starting twice never doubles the subscription', () async {
      var loads = 0;
      when(() => getSheet(id)).thenAnswer((_) async {
        loads++;
        return Ok(sheet);
      });
      final bloc = StudentSheetBloc(getSheet, watch)
        ..add(const StudentSheetEvent.started(studentId: id))
        ..add(const StudentSheetEvent.started(studentId: id));
      await pumpEventQueue();
      final before = loads;

      changes.add(null);
      await pumpEventQueue();

      verify(() => watch(id)).called(1);
      expect(loads, before + 1);
      await bloc.close();
    });

    test(
      'a refusal after the change shows as a failure, then recovers',
      () async {
        var denied = false;
        when(() => getSheet(id)).thenAnswer(
          (_) async => denied
              ? const Err<StudentSheet>(
                  ServiceFailure(ServiceFailureCode.denied),
                )
              : Ok(sheet),
        );
        final bloc = StudentSheetBloc(getSheet, watch);
        final log = StreamLog(bloc.stream);
        bloc.add(const StudentSheetEvent.started(studentId: id));
        await log.settle();

        denied = true;
        changes.addError(const ServiceFailure(ServiceFailureCode.denied));
        await log.settle();
        expect(log.last.status, StudentSheetStatus.failure);

        denied = false;
        bloc.add(const StudentSheetEvent.refreshed());
        await log.settle();
        expect(log.last.status, StudentSheetStatus.ready);
        await log.cancel();
        await bloc.close();
      },
    );

    test('a retry after a failure reopens the watch', () async {
      var calls = 0;
      when(() => getSheet(id)).thenAnswer(
        (_) async => calls++ == 0
            ? const Err<StudentSheet>(ServiceFailure(ServiceFailureCode.denied))
            : Ok(sheet),
      );
      final bloc = StudentSheetBloc(getSheet, watch)
        ..add(const StudentSheetEvent.started(studentId: id));
      await pumpEventQueue();

      bloc.add(const StudentSheetEvent.refreshed());
      await pumpEventQueue();

      verify(() => watch(id)).called(2);
      await bloc.close();
    });

    test('opening another student follows the new one, not the old', () async {
      const second = StudentId('s2');
      final secondChanges = StreamController<void>.broadcast();
      addTearDown(secondChanges.close);
      when(() => watch(second)).thenAnswer((_) => secondChanges.stream);
      var loadsOfSecond = 0;
      when(() => getSheet(id)).thenAnswer((_) async => Ok(sheet));
      when(() => getSheet(second)).thenAnswer((_) async {
        loadsOfSecond++;
        return Ok(sheet);
      });
      final bloc = StudentSheetBloc(getSheet, watch)
        ..add(const StudentSheetEvent.started(studentId: id));
      await pumpEventQueue();

      bloc.add(const StudentSheetEvent.started(studentId: second));
      await pumpEventQueue();
      final before = loadsOfSecond;

      expect(changes.hasListener, isFalse, reason: 'ancienne écoute fermée');
      expect(secondChanges.hasListener, isTrue);
      changes.add(null);
      await pumpEventQueue();
      expect(loadsOfSecond, before, reason: "l'ancien élève ne relit plus");
      secondChanges.add(null);
      await pumpEventQueue();
      expect(loadsOfSecond, before + 1);
      expect(bloc.state.studentId, second);
      await bloc.close();
    });

    test('closing releases the watch and ignores later changes', () async {
      var loads = 0;
      when(() => getSheet(id)).thenAnswer((_) async {
        loads++;
        return Ok(sheet);
      });
      final bloc = StudentSheetBloc(getSheet, watch)
        ..add(const StudentSheetEvent.started(studentId: id));
      await pumpEventQueue();

      await bloc.close();
      final before = loads;
      changes.add(null);
      await pumpEventQueue();

      expect(changes.hasListener, isFalse);
      expect(loads, before);
    });
  });
}
