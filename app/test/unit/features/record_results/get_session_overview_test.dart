import 'package:billard_cfa/features/record_results/domain/get_session_overview.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late GetSessionOverview overview;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['zoe', 'abel', 'absent']);
    await world.session(present: {'zoe', 'abel'});
    overview = GetSessionOverview(
      world.sessions,
      world.groups,
      world.students,
      world.attempts,
      world.catalogueRepository,
      world.sheets,
      world.config,
    );
  });

  test('gives the group, the present students sorted by first name', () async {
    final result = ok(await overview(const SessionId('x1')));

    expect(result.session.id, const SessionId('x1'));
    expect(result.groupName, 'Groupe');
    expect(result.students.map((s) => s.firstName), ['abel', 'zoe']);
    expect(result.catalogue, world.catalogue);
    expect(result.maxPassesPerExercise, 2);
    expect(result.passesRequired, 5);
  });

  test('lists the passes of the session in order', () async {
    await world.attempts.add(
      attempt(ref('a', 1), potted: 4, student: 'zoe', id: 'p1'),
    );
    await world.attempts.add(
      attempt(ref('a', 1), potted: 2, student: 'zoe', id: 'p2', passIndex: 2),
    );
    await world.attempts.add(
      attempt(ref('b', 2), potted: 3, student: 'abel', id: 'p3'),
    );
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, student: 'abel', id: 'q', session: 'x2'),
    );

    final result = ok(await overview(const SessionId('x1')));

    expect(result.attempts.map((a) => a.id.value), ['p1', 'p2', 'p3']);
    expect(result.passesOf(const StudentId('zoe'), ref('a', 1)), 2);
    expect(result.passesOf(const StudentId('abel'), ref('a', 1)), 0);
  });

  test('names the catalogue session it notes, when known', () async {
    await world.session(
      id: 'x2',
      dayOfMonth: 2,
      sheet: SheetId('demi-bille-2'),
    );
    await world.session(id: 'x3', dayOfMonth: 3, sheet: SheetId('inconnue-9'));

    expect(ok(await overview(const SessionId('x1'))).sheet, isNull);
    expect(ok(await overview(const SessionId('x2'))).sheet?.part, 2);
    expect(
      ok(await overview(const SessionId('x2'))).sheet?.title,
      'Quantité demi-bille',
    );
    expect(ok(await overview(const SessionId('x3'))).sheet, isNull);
  });

  test('refuses an unknown session', () async {
    final result = await overview(const SessionId('nope'));

    expect(err(result), isA<NotFound>());
  });
}
