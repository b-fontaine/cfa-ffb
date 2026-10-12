import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_students/domain/enroll_student.dart';
import 'package:billard_cfa/features/manage_students/domain/get_student.dart';
import 'package:billard_cfa/features/manage_students/domain/rename_student.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_form_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';

class _MockGetStudent extends Mock implements GetStudent;

class _MockEnrollStudent extends Mock implements EnrollStudent;

class _MockRenameStudent extends Mock implements RenameStudent;

void main() {
  late _MockGetStudent getStudent;
  late _MockEnrollStudent enroll;
  late _MockRenameStudent rename;
  final today = DateTime(2026, 10, 12);
  const id = StudentId('s1');
  final student = Student.enroll(
    id: id,
    firstName: 'Lea',
    audience: Audience.adults,
    since: DateTime(2026, 9),
  );

  setUpAll(() {
    registerFallbackValue(Audience.children);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    getStudent = _MockGetStudent();
    enroll = _MockEnrollStudent();
    rename = _MockRenameStudent();
  });

  StudentFormBloc build() => StudentFormBloc(
    getStudent,
    enroll,
    rename,
    FixedClock(DateTime(2026, 10, 12, 18)),
  );

  blocTest<StudentFormBloc, StudentFormState>(
    'is ready at once to create a student',
    build: build,
    act: (bloc) => bloc.add(const StudentFormEvent.started()),
    expect: () => [const StudentFormState(status: StudentFormStatus.ready)],
  );

  blocTest<StudentFormBloc, StudentFormState>(
    'loads the student to edit',
    build: () {
      when(() => getStudent(id)).thenAnswer((_) async => Ok(student));
      return build();
    },
    act: (bloc) => bloc.add(const StudentFormEvent.started(studentId: id)),
    expect: () => [
      const StudentFormState(),
      StudentFormState(status: StudentFormStatus.ready, student: student),
    ],
  );

  blocTest<StudentFormBloc, StudentFormState>(
    'reports an unknown student to edit',
    build: () {
      when(() => getStudent(id))
          .thenAnswer((_) async => const Err(NotFound('student', 's1')));
      return build();
    },
    seed: () => const StudentFormState(status: StudentFormStatus.ready),
    act: (bloc) => bloc.add(const StudentFormEvent.started(studentId: id)),
    expect: () => [
      const StudentFormState(),
      const StudentFormState(
        status: StudentFormStatus.failure,
        failure: NotFound('student', 's1'),
      ),
    ],
  );

  blocTest<StudentFormBloc, StudentFormState>(
    'enrols a new student with the localised group name',
    build: () {
      when(
        () => enroll(
          firstName: 'Léa',
          audience: Audience.children,
          today: today,
          groupName: 'Groupe enfants',
        ),
      ).thenAnswer(
        (_) async => Ok(
          EnrolledStudent(
            student: student,
            group: Group(
              id: const GroupId('g'),
              seasonId: const SeasonId('x'),
              name: 'Groupe enfants',
              audience: Audience.children,
            ),
          ),
        ),
      );
      return build();
    },
    seed: () => const StudentFormState(status: StudentFormStatus.ready),
    act: (bloc) => bloc.add(
      const StudentFormEvent.submitted(
        firstName: 'Léa',
        audience: Audience.children,
        groupName: 'Groupe enfants',
      ),
    ),
    expect: () => [
      const StudentFormState(status: StudentFormStatus.saving),
      StudentFormState(status: StudentFormStatus.saved, saved: student),
    ],
  );

  blocTest<StudentFormBloc, StudentFormState>(
    'stays on the form when the student is refused',
    build: () {
      when(
        () => enroll(
          firstName: ' ',
          audience: Audience.children,
          today: today,
          groupName: 'g',
        ),
      ).thenAnswer(
        (_) async => const Err(InvariantViolation(InvariantCode.blankName)),
      );
      return build();
    },
    seed: () => const StudentFormState(status: StudentFormStatus.ready),
    act: (bloc) => bloc.add(
      const StudentFormEvent.submitted(
        firstName: ' ',
        audience: Audience.children,
        groupName: 'g',
      ),
    ),
    expect: () => [
      const StudentFormState(status: StudentFormStatus.saving),
      const StudentFormState(
        status: StudentFormStatus.ready,
        failure: InvariantViolation(InvariantCode.blankName),
      ),
    ],
  );

  blocTest<StudentFormBloc, StudentFormState>(
    'renames the student being edited, never changing the audience',
    build: () {
      when(() => rename(studentId: id, firstName: 'Léa'))
          .thenAnswer((_) async => Ok(student));
      return build();
    },
    seed: () =>
        StudentFormState(status: StudentFormStatus.ready, student: student),
    act: (bloc) => bloc.add(
      const StudentFormEvent.submitted(
        firstName: 'Léa',
        audience: Audience.children,
        groupName: 'g',
      ),
    ),
    expect: () => [
      StudentFormState(status: StudentFormStatus.saving, student: student),
      StudentFormState(
        status: StudentFormStatus.saved,
        student: student,
        saved: student,
      ),
    ],
    verify: (_) {
      verifyNever(
        () => enroll(
          firstName: any(named: 'firstName'),
          audience: any(named: 'audience'),
          today: any(named: 'today'),
          groupName: any(named: 'groupName'),
        ),
      );
    },
  );
}
