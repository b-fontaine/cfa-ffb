import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/delete_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  late InMemorySessionRepository repository;
  late DeleteSession delete;

  setUp(() async {
    repository = InMemorySessionRepository();
    await repository.add(
      Session(
        id: 'p1',
        title: 'Cours',
        date: day(12),
        audience: Audience.adults,
        sheetId: SheetId('demi-bille-2'),
      ),
    );
    await repository.add(
      Session(
        id: 'p2',
        title: 'Libre',
        date: day(12),
        audience: Audience.children,
      ),
    );
    delete = DeleteSession(repository);
  });

  test('removes the planned session and keeps the others', () async {
    await delete('p1');

    final left = await repository.getAll();
    expect(left.map((s) => s.id), ['p2']);
  });

  test('does nothing for an unknown session', () async {
    await delete('inconnue');

    expect((await repository.getAll()).map((s) => s.id), ['p1', 'p2']);
  });
}
