import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements SessionRepository;

void main() {
  test('returns the repository sessions', () async {
    final repository = _MockRepository();
    const sessions = [Session(id: '1', title: 'a', audience: Audience.adults)];
    when(repository.getAll).thenAnswer((_) async => sessions);

    expect(await ListSessions(repository)(), sessions);
  });
}
