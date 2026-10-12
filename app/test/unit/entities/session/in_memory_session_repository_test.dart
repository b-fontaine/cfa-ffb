import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts empty', () async {
    expect(await InMemorySessionRepository().getAll(), isEmpty);
  });

  test('returns added sessions in insertion order', () async {
    final repository = InMemorySessionRepository();
    const first = Session(id: '1', title: 'a', audience: Audience.children);
    const second = Session(id: '2', title: 'b', audience: Audience.adults);

    await repository.add(first);
    await repository.add(second);

    expect(await repository.getAll(), [first, second]);
  });

  test('exposes an unmodifiable snapshot', () async {
    final repository = InMemorySessionRepository();
    final sessions = await repository.getAll();

    expect(
      () => sessions.add(
        const Session(id: '1', title: 'a', audience: Audience.children),
      ),
      throwsUnsupportedError,
    );
  });
}
