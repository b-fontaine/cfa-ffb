import 'package:billard_cfa/app/club_scoped.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_rig.dart';

const _nice = ClubMembership(
  clubId: ClubId('nice'),
  clubName: 'Club Nice',
  role: Role.director,
);
const _lyon = ClubMembership(
  clubId: ClubId('lyon'),
  clubName: 'Club Lyon',
  role: Role.teacher,
);

/// Une page avec un état local : un compteur incrémenté par un bouton.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('count $count'),
  );
}

void main() {
  late AuthRig rig;

  setUp(() {
    rig = AuthRig();
    final coach = rig.auth.seed(email: 'coach@example.org', password: 'pw');
    rig.auth.restoreSession('coach@example.org');
    rig.memberships
      ..grant(coach.id, _nice)
      ..grant(coach.id, _lyon);
    addTearDown(rig.cubit.close);
  });

  Future<void> pumpScoped(WidgetTester tester) async {
    await tester.runAsync(() async {
      await rig.memory.write(rig.auth.current!.id, _nice);
      await rig.cubit.start();
      await pumpEventQueue();
    });
    await tester.pumpWidget(
      BlocProvider.value(
        value: rig.cubit,
        child: const MaterialApp(home: ClubScoped(child: _Counter())),
      ),
    );
  }

  testWidgets('switching club resets the local state of the screen', (
    tester,
  ) async {
    await pumpScoped(tester);
    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    await tester.runAsync(() => rig.cubit.chooseClub(_lyon));
    await tester.pump();

    expect(find.text('count 0'), findsOneWidget);
    expect(find.text('count 1'), findsNothing);
  });

  testWidgets('keeping the same club keeps the local state', (tester) async {
    await pumpScoped(tester);
    await tester.tap(find.text('count 0'));
    await tester.pump();

    await tester.runAsync(() => rig.cubit.chooseClub(_nice));
    await tester.pump();
    await tester.runAsync(rig.cubit.refresh);
    await tester.pump();

    expect(find.text('count 1'), findsOneWidget);
  });

  testWidgets('a new role in the same club resets the screen', (tester) async {
    await pumpScoped(tester);
    await tester.tap(find.text('count 0'));
    await tester.pump();

    // Le directeur du club Nice devient enseignant : mêmes clubs, autre
    // rôle.
    final coach = rig.auth.current!;
    rig.memberships
      ..revokeAll(coach.id)
      ..grant(
        coach.id,
        const ClubMembership(
          clubId: ClubId('nice'),
          clubName: 'Club Nice',
          role: Role.teacher,
        ),
      );
    await tester.runAsync(rig.cubit.refresh);
    await tester.pump();

    expect(find.text('count 0'), findsOneWidget);
    expect(find.text('count 1'), findsNothing);
  });

  testWidgets('new groups for the same role reset the screen', (tester) async {
    await pumpScoped(tester);
    await tester.tap(find.text('count 0'));
    await tester.pump();

    // L'enseignant reçoit un groupe : même club, même rôle, autre périmètre.
    final coach = rig.auth.current!;
    rig.memberships
      ..revokeAll(coach.id)
      ..grant(
        coach.id,
        const ClubMembership(
          clubId: ClubId('nice'),
          clubName: 'Club Nice',
          role: Role.director,
          groupIds: [GroupId('g1')],
          studentIds: [StudentId('s1')],
        ),
      );
    await tester.runAsync(rig.cubit.refresh);
    await tester.pump();

    expect(find.text('count 0'), findsOneWidget);
    expect(find.text('count 1'), findsNothing);
  });

  testWidgets('the same groups and students in another order keep the screen', (
    tester,
  ) async {
    final coach = rig.auth.current!;
    rig.memberships
      ..revokeAll(coach.id)
      ..grant(
        coach.id,
        const ClubMembership(
          clubId: ClubId('nice'),
          clubName: 'Club Nice',
          role: Role.guardian,
          groupIds: [GroupId('g1'), GroupId('g2')],
          studentIds: [StudentId('s1'), StudentId('s2')],
        ),
      );
    await pumpScoped(tester);
    await tester.tap(find.text('count 0'));
    await tester.pump();

    rig.memberships
      ..revokeAll(coach.id)
      ..grant(
        coach.id,
        const ClubMembership(
          clubId: ClubId('nice'),
          clubName: 'Club Nice',
          role: Role.guardian,
          groupIds: [GroupId('g2'), GroupId('g1')],
          studentIds: [StudentId('s2'), StudentId('s1')],
        ),
      );
    await tester.runAsync(rig.cubit.refresh);
    await tester.pump();

    expect(find.text('count 1'), findsOneWidget);
  });
}
