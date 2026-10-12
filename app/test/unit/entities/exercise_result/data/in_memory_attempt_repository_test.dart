import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  late InMemoryAttemptRepository repository;

  setUp(() async {
    repository = InMemoryAttemptRepository();
    await repository.add(attempt(ref('a', 1), potted: 3, id: '1'));
    await repository.add(
      attempt(ref('a', 2), potted: 3, session: 'x2', id: '2'),
    );
    await repository.add(
      attempt(ref('a', 1), potted: 3, student: 's2', id: '3'),
    );
  });

  test('lists the attempts of a student', () async {
    final attempts = await repository.forStudent(const StudentId('s1'));

    expect(attempts.map((a) => a.id.value), ['1', '2']);
  });

  test('lists the attempts of a session', () async {
    final attempts = await repository.forSession(const SessionId('x1'));

    expect(attempts.map((a) => a.id.value), ['1', '3']);
  });

  test('returns nothing for an unknown student', () async {
    expect(await repository.forStudent(const StudentId('zz')), isEmpty);
  });
}
