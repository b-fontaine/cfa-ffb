import 'package:billard_cfa/features/student_showcase/domain/get_student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/presentation/bloc/showcase_cubit.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGet extends Mock implements GetStudentShowcase;

const _showcase = StudentShowcase(
  firstName: 'Léa',
  rows: [],
  current: null,
  validatedCount: 0,
  finishedTechniques: 0,
  techniqueCount: 0,
  toStart: true,
  passesRequired: 5,
);

void main() {
  late _MockGet get;
  const student = StudentId('s1');

  setUp(() => get = _MockGet());

  blocTest<ShowcaseCubit, ShowcaseState>(
    'loads the showcase of the student',
    build: () {
      when(() => get(student)).thenAnswer((_) async => const Ok(_showcase));
      return ShowcaseCubit(get);
    },
    act: (cubit) => cubit.load(student),
    expect: () => [
      const ShowcaseState(status: ShowcaseStatus.ready, showcase: _showcase),
    ],
  );

  blocTest<ShowcaseCubit, ShowcaseState>(
    'reports an unknown student',
    build: () {
      when(() => get(student))
          .thenAnswer((_) async => const Err(NotFound('student', 's1')));
      return ShowcaseCubit(get);
    },
    act: (cubit) => cubit.load(student),
    expect: () => [
      const ShowcaseState(
        status: ShowcaseStatus.failure,
        failure: NotFound('student', 's1'),
      ),
    ],
  );
}
