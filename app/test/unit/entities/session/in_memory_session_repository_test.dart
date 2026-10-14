import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

Session _session(String id, Audience audience) =>
    Session(id: id, title: id, date: day(12), audience: audience);

void main() {
  test('starts empty', () async {
    expect(await InMemorySessionRepository().getAll(), isEmpty);
  });

  test('returns added sessions in insertion order', () async {
    final repository = InMemorySessionRepository();
    final first = _session('1', Audience.children);
    final second = _session('2', Audience.adults);

    await repository.add(first);
    await repository.add(second);

    expect(await repository.getAll(), [first, second]);
  });

  test('exposes an unmodifiable snapshot', () async {
    final repository = InMemorySessionRepository();
    final sessions = await repository.getAll();

    expect(
      () => sessions.add(_session('1', Audience.children)),
      throwsUnsupportedError,
    );
  });
}
