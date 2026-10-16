import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/run_sheet_world.dart';

void main() {
  late RunSheetWorld world;

  setUp(() async {
    world = RunSheetWorld();
    await world.sessions.add(
      Session(
        id: 'p1',
        title: 'Cours',
        date: day(19),
        audience: Audience.adults,
        groupId: const GroupId('g1'),
      ),
    );
  });

  group('recordDefaults', () {
    test(
      'proposes nothing without planned session nor previous record',
      () async {
        final cubit = await world.cubit('demi-bille-1');
        addTearDown(cubit.close);

        final defaults = cubit.state.recordDefaults;

        expect(defaults.group, isNull);
        expect(defaults.date, isNull);
        expect(defaults.absent, isEmpty);
      },
    );

    test('takes the group and the day of the planned session', () async {
      final cubit = await world.cubit('demi-bille-1', sessionId: 'p1');
      addTearDown(cubit.close);

      final defaults = cubit.state.recordDefaults;

      expect(defaults.group, const GroupId('g1'));
      expect(defaults.date, day(19));
      expect(defaults.absent, isEmpty);
    });

    test('prefers the choice of a previous record of this guide', () async {
      final cubit = await world.cubit('demi-bille-1', sessionId: 'p1');
      addTearDown(cubit.close);

      cubit.recordChosen(
        recordId: const SessionId('x9'),
        group: const GroupId('g2'),
        date: day(20),
        absent: {const StudentId('s1')},
      );

      final defaults = cubit.state.recordDefaults;

      expect(defaults.group, const GroupId('g2'));
      expect(defaults.date, day(20));
      expect(defaults.absent, {const StudentId('s1')});
      expect(cubit.state.recordChoice?.recordId, const SessionId('x9'));
    });
  });
}
