import 'package:billard_cfa/features/track_group/domain/get_group_overview.dart';
import 'package:billard_cfa/features/track_group/domain/group_alerts.dart';
import 'package:billard_cfa/features/track_group/domain/group_attendance.dart';
import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/features/track_group/domain/list_group_alerts.dart';
import 'package:billard_cfa/features/track_group/presentation/bloc/group_alerts_cubit.dart';
import 'package:billard_cfa/features/track_group/presentation/bloc/group_overview_cubit.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOverview extends Mock implements GetGroupOverview;

class _MockAlerts extends Mock implements ListGroupAlerts;

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 18, 30);
}

const _grid = GroupGrid(
  groupId: GroupId('g1'),
  name: 'Jeunes',
  students: [],
  rows: [],
  attendance: GroupAttendance(
    present: 0,
    possible: 0,
    sessionCount: 0,
    recent: [],
  ),
  alerts: [],
);

void main() {
  const gid = GroupId('g1');
  final today = DateTime(2026, 10, 12);

  group('GroupOverviewCubit', () {
    late _MockOverview overview;

    setUp(() => overview = _MockOverview());

    Future<Result<GroupGrid>> call() => overview(groupId: gid, today: today);

    blocTest<GroupOverviewCubit, GroupOverviewState>(
      'loads the grid of the group with the day of the clock',
      build: () {
        when(call).thenAnswer((_) async => const Ok(_grid));
        return GroupOverviewCubit(overview, _FixedClock());
      },
      act: (cubit) => cubit.load(gid),
      expect: () => [
        const GroupOverviewState(groupId: gid),
        const GroupOverviewState(
          groupId: gid,
          status: GroupOverviewStatus.ready,
          grid: _grid,
        ),
      ],
      verify: (_) => verify(call).called(1),
    );

    blocTest<GroupOverviewCubit, GroupOverviewState>(
      'reports the failure of an unknown group',
      build: () {
        when(call).thenAnswer((_) async => const Err(NotFound('group', 'g1')));
        return GroupOverviewCubit(overview, _FixedClock());
      },
      act: (cubit) => cubit.load(gid),
      expect: () => [
        const GroupOverviewState(groupId: gid),
        const GroupOverviewState(
          groupId: gid,
          status: GroupOverviewStatus.failure,
          failure: NotFound('group', 'g1'),
        ),
      ],
    );

    blocTest<GroupOverviewCubit, GroupOverviewState>(
      'reloads the same group on demand',
      build: () {
        when(call).thenAnswer((_) async => const Ok(_grid));
        return GroupOverviewCubit(overview, _FixedClock());
      },
      act: (cubit) async {
        await cubit.load(gid);
        await cubit.reload();
      },
      verify: (_) => verify(call).called(2),
    );
  });

  group('GroupAlertsCubit', () {
    late _MockAlerts alerts;

    setUp(() => alerts = _MockAlerts());

    Future<Result<GroupAlertList>> call() => alerts(today: today);

    const list = GroupAlertList(
      lines: [
        GroupAlertLine(
          groupId: gid,
          groupName: 'Jeunes',
          alert: GroupAlert(
            blockId: 'a',
            blockTitle: 'Bloc a',
            failed: 2,
            members: 3,
          ),
        ),
      ],
      total: 1,
    );

    blocTest<GroupAlertsCubit, GroupAlertsState>(
      'loads the alerts of the groups',
      build: () {
        when(call).thenAnswer((_) async => const Ok(list));
        return GroupAlertsCubit(alerts, _FixedClock());
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const GroupAlertsState(status: GroupAlertsStatus.ready, alerts: list),
      ],
    );

    blocTest<GroupAlertsCubit, GroupAlertsState>(
      'reports a failure',
      build: () {
        when(call).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.invalidRules)),
        );
        return GroupAlertsCubit(alerts, _FixedClock());
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const GroupAlertsState(
          status: GroupAlertsStatus.failure,
          failure: InvariantViolation(InvariantCode.invalidRules),
        ),
      ],
    );
  });
}
