import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEraseStudent extends Mock implements EraseStudent;

void main() {
  late _MockEraseStudent erase;
  const id = StudentId('s1');

  setUp(() => erase = _MockEraseStudent());

  blocTest<StudentErasureBloc, StudentErasureState>(
    'erases the student then reports it',
    build: () {
      when(() => erase(id)).thenAnswer((_) async => const Ok(null));
      return StudentErasureBloc(erase);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.requested(studentId: id)),
    expect: () => [
      const StudentErasureState(status: StudentErasureStatus.working),
      const StudentErasureState(status: StudentErasureStatus.erased),
    ],
    verify: (_) => verify(() => erase(id)).called(1),
  );

  blocTest<StudentErasureBloc, StudentErasureState>(
    'reports the failure and keeps the student',
    build: () {
      when(() => erase(id))
          .thenAnswer((_) async => const Err(NotFound('student', 's1')));
      return StudentErasureBloc(erase);
    },
    act: (bloc) => bloc.add(const StudentErasureEvent.requested(studentId: id)),
    expect: () => [
      const StudentErasureState(status: StudentErasureStatus.working),
      const StudentErasureState(
        status: StudentErasureStatus.failure,
        failure: NotFound('student', 's1'),
      ),
    ],
  );
}
