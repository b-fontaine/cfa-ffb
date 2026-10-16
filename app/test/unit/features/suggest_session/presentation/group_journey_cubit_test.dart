import 'dart:async';

import 'package:billard_cfa/features/suggest_session/domain/get_group_journey.dart';
import 'package:billard_cfa/features/suggest_session/domain/group_journey.dart';
import 'package:billard_cfa/features/suggest_session/domain/list_journey_groups.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/group_journey_cubit.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockJourney extends Mock implements GetGroupJourney;

class _MockGroups extends Mock implements ListJourneyGroups;

void main() {
  late _MockJourney getJourney;
  late _MockGroups listGroups;
  const g1 = GroupId('g1');
  const g2 = GroupId('g2');
  final first = GroupJourney(next: SheetId('posture-1'));
  final second = GroupJourney(next: SheetId('posture-2'));

  const choices = [GroupChoice(g1, 'Enfants'), GroupChoice(g2, 'Adultes')];

  setUpAll(() => registerFallbackValue(const GroupId('any')));

  setUp(() {
    getJourney = _MockJourney();
    listGroups = _MockGroups();
  });

  test('starts with no group and no mark', () {
    final cubit = GroupJourneyCubit(getJourney, listGroups);

    expect(cubit.state.status, GroupJourneyStatus.none);
    expect(cubit.state.marksFor([SheetId('posture-1')]), isEmpty);
  });

  blocTest<GroupJourneyCubit, GroupJourneyState>(
    'loads the journey of the chosen group',
    setUp: () => when(() => getJourney(g1)).thenAnswer((_) async => Ok(first)),
    build: () => GroupJourneyCubit(getJourney, listGroups),
    act: (cubit) => cubit.select(g1),
    expect: () => [
      const GroupJourneyState(status: GroupJourneyStatus.loading, groupId: g1),
      GroupJourneyState(
        status: GroupJourneyStatus.ready,
        groupId: g1,
        journey: first,
      ),
    ],
  );

  blocTest<GroupJourneyCubit, GroupJourneyState>(
    'choosing no group clears the marks',
    setUp: () => when(() => getJourney(g1)).thenAnswer((_) async => Ok(first)),
    build: () => GroupJourneyCubit(getJourney, listGroups),
    act: (cubit) async {
      await cubit.select(g1);
      await cubit.select(null);
    },
    skip: 2,
    expect: () => [const GroupJourneyState()],
  );

  blocTest<GroupJourneyCubit, GroupJourneyState>(
    'a failure keeps the group and shows no mark',
    setUp: () => when(
      () => getJourney(g1),
    ).thenAnswer((_) async => const Err<GroupJourney>(NotFound('group', 'g1'))),
    build: () => GroupJourneyCubit(getJourney, listGroups),
    act: (cubit) => cubit.select(g1),
    skip: 1,
    expect: () => [
      const GroupJourneyState(
        status: GroupJourneyStatus.failure,
        groupId: g1,
        failure: NotFound('group', 'g1'),
      ),
    ],
  );

  test('the last choice wins over a slower earlier one', () async {
    final slow = Completer<Result<GroupJourney>>();
    when(() => getJourney(g1)).thenAnswer((_) => slow.future);
    when(() => getJourney(g2)).thenAnswer((_) async => Ok(second));
    final cubit = GroupJourneyCubit(getJourney, listGroups);

    final early = cubit.select(g1);
    await cubit.select(g2);
    slow.complete(Ok(first));
    await early;

    expect(cubit.state.groupId, g2);
    expect(cubit.state.journey, second);
    expect(cubit.state.marksFor([SheetId('posture-2')]), {
      SheetId('posture-2'): JourneyMark.next,
    });
  });

  test('ignores the result once closed', () async {
    final slow = Completer<Result<GroupJourney>>();
    when(() => getJourney(g1)).thenAnswer((_) => slow.future);
    final cubit = GroupJourneyCubit(getJourney, listGroups);

    final pending = cubit.select(g1);
    await cubit.close();
    slow.complete(Ok(first));

    await pending;
    expect(cubit.isClosed, isTrue);
  });

  group('load', () {
    blocTest<GroupJourneyCubit, GroupJourneyState>(
      'offers the groups and chooses none by default',
      setUp: () =>
          when(() => listGroups()).thenAnswer((_) async => const Ok(choices)),
      build: () => GroupJourneyCubit(getJourney, listGroups),
      act: (cubit) => cubit.load(),
      expect: () => [const GroupJourneyState(choices: choices)],
    );

    blocTest<GroupJourneyCubit, GroupJourneyState>(
      'chooses the group of the address when it is offered',
      setUp: () {
        when(() => listGroups()).thenAnswer((_) async => const Ok(choices));
        when(() => getJourney(g2)).thenAnswer((_) async => Ok(second));
      },
      build: () => GroupJourneyCubit(getJourney, listGroups),
      act: (cubit) => cubit.load(initial: g2),
      expect: () => [
        const GroupJourneyState(choices: choices),
        const GroupJourneyState(
          choices: choices,
          status: GroupJourneyStatus.loading,
          groupId: g2,
        ),
        GroupJourneyState(
          choices: choices,
          status: GroupJourneyStatus.ready,
          groupId: g2,
          journey: second,
        ),
      ],
    );

    blocTest<GroupJourneyCubit, GroupJourneyState>(
      'ignores a group of the address that is not offered',
      setUp: () =>
          when(() => listGroups()).thenAnswer((_) async => const Ok(choices)),
      build: () => GroupJourneyCubit(getJourney, listGroups),
      act: (cubit) => cubit.load(initial: const GroupId('unknown')),
      expect: () => [const GroupJourneyState(choices: choices)],
      verify: (_) => verifyNever(() => getJourney(any())),
    );

    blocTest<GroupJourneyCubit, GroupJourneyState>(
      'keeps the groups offered when a group is chosen then cleared',
      setUp: () {
        when(() => listGroups()).thenAnswer((_) async => const Ok(choices));
        when(() => getJourney(g1)).thenAnswer((_) async => Ok(first));
      },
      build: () => GroupJourneyCubit(getJourney, listGroups),
      act: (cubit) async {
        await cubit.load();
        await cubit.select(g1);
        await cubit.select(null);
      },
      skip: 3,
      expect: () => [const GroupJourneyState(choices: choices)],
    );

    blocTest<GroupJourneyCubit, GroupJourneyState>(
      'keeps the failure when the groups cannot be listed',
      setUp: () => when(() => listGroups()).thenAnswer(
        (_) async => const Err<List<GroupChoice>>(NotFound('g', '')),
      ),
      build: () => GroupJourneyCubit(getJourney, listGroups),
      act: (cubit) => cubit.load(),
      expect: () => [const GroupJourneyState(failure: NotFound('g', ''))],
    );
  });
}
