import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/closure_plan.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/features/close_season/domain/prepare_season_closure.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/season_closure_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';
import '../../../../support/fixtures.dart';

class _MockPrepare extends Mock implements PrepareSeasonClosure;

class _MockClose extends Mock implements CloseSeason;

void main() {
  late _MockPrepare prepare;
  late _MockClose close;
  const seasonId = SeasonId('season');
  const lea = StudentId('lea');
  const hugo = StudentId('hugo');
  final season = Season(
    id: seasonId,
    label: '2026-2027',
    startDate: day(1),
    endDate: day(31),
  );
  final plan = ClosurePlan(
    season: season,
    closedOn: day(12),
    early: true,
    audiences: const [],
    proposals: const [
      ClosureProposal(
        studentId: lea,
        firstName: 'Léa',
        audience: Audience.children,
        choice: ClosureChoice.keep,
        reason: ClosureReason.carriedOver,
      ),
      ClosureProposal(
        studentId: hugo,
        firstName: 'Hugo',
        audience: Audience.children,
        choice: ClosureChoice.erase,
        reason: ClosureReason.inactive,
      ),
    ],
    plannedToDrop: 2,
  );
  final ready = SeasonClosureState(
    status: SeasonClosureStatus.ready,
    plan: plan,
    choices: const {lea: ClosureChoice.keep, hugo: ClosureChoice.erase},
  );

  setUpAll(() {
    registerFallbackValue(seasonId);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    prepare = _MockPrepare();
    close = _MockClose();
  });

  SeasonClosureBloc build() =>
      SeasonClosureBloc(prepare, close, FixedClock(DateTime(2026, 10, 12, 9)));

  blocTest<SeasonClosureBloc, SeasonClosureState>(
    'starts from the proposal of the rule',
    build: () {
      when(() => prepare(seasonId: seasonId, today: day(12)))
          .thenAnswer((_) async => Ok(plan));
      return build();
    },
    act: (bloc) =>
        bloc.add(const SeasonClosureEvent.started(seasonId: seasonId)),
    expect: () => [const SeasonClosureState(), ready],
    verify: (bloc) {
      expect(bloc.state.erasedCount, 1);
      expect(bloc.state.keptCount, 1);
    },
  );

  blocTest<SeasonClosureBloc, SeasonClosureState>(
    'reports a season that cannot be closed',
    build: () {
      when(() => prepare(seasonId: seasonId, today: day(12))).thenAnswer(
        (_) async =>
            const Err(InvariantViolation(InvariantCode.seasonAlreadyClosed)),
      );
      return build();
    },
    act: (bloc) =>
        bloc.add(const SeasonClosureEvent.started(seasonId: seasonId)),
    expect: () => [
      const SeasonClosureState(),
      const SeasonClosureState(
        status: SeasonClosureStatus.failure,
        failure: InvariantViolation(InvariantCode.seasonAlreadyClosed),
      ),
    ],
  );

  blocTest<SeasonClosureBloc, SeasonClosureState>(
    'lets the animator reverse one line',
    build: build,
    seed: () => ready,
    act: (bloc) => bloc.add(
      const SeasonClosureEvent.choiceSet(
        studentId: hugo,
        choice: ClosureChoice.keep,
      ),
    ),
    expect: () => [
      ready.copyWith(
        choices: const {lea: ClosureChoice.keep, hugo: ClosureChoice.keep},
      ),
    ],
  );

  blocTest<SeasonClosureBloc, SeasonClosureState>(
    'sets every line at once',
    build: build,
    seed: () => ready,
    act: (bloc) =>
        bloc.add(const SeasonClosureEvent.allSet(choice: ClosureChoice.erase)),
    expect: () => [
      ready.copyWith(
        choices: const {lea: ClosureChoice.erase, hugo: ClosureChoice.erase},
      ),
    ],
  );

  blocTest<SeasonClosureBloc, SeasonClosureState>(
    'toggles the two options',
    build: build,
    seed: () => ready,
    act: (bloc) => bloc
      ..add(const SeasonClosureEvent.prepareNextSet(value: false))
      ..add(const SeasonClosureEvent.dropPlannedSet(value: false)),
    expect: () => [
      ready.copyWith(prepareNext: false),
      ready.copyWith(prepareNext: false, dropPlanned: false),
    ],
  );

  blocTest<SeasonClosureBloc, SeasonClosureState>(
    'closes the season erasing only the chosen students',
    build: () {
      when(
        () => close(
          seasonId: seasonId,
          closedOn: day(12),
          erase: {hugo},
          prepareNext: any(named: 'prepareNext'),
          dropPlanned: any(named: 'dropPlanned'),
        ),
      ).thenAnswer(
        (_) async => const Ok(
          ClosureResult(
            erased: 1,
            kept: 1,
            groupsPrepared: 1,
            plannedDropped: 2,
          ),
        ),
      );
      return build();
    },
    seed: () => ready,
    act: (bloc) => bloc.add(const SeasonClosureEvent.confirmed()),
    expect: () => [
      ready.copyWith(status: SeasonClosureStatus.closing),
      ready.copyWith(
        status: SeasonClosureStatus.closed,
        result: const ClosureResult(
          erased: 1,
          kept: 1,
          groupsPrepared: 1,
          plannedDropped: 2,
        ),
      ),
    ],
  );

  blocTest<SeasonClosureBloc, SeasonClosureState>(
    'stays on the assistant when the closure is refused',
    build: () {
      when(
        () => close(
          seasonId: seasonId,
          closedOn: day(12),
          erase: {hugo},
          prepareNext: any(named: 'prepareNext'),
          dropPlanned: any(named: 'dropPlanned'),
        ),
      ).thenAnswer(
        (_) async =>
            const Err(InvariantViolation(InvariantCode.seasonAlreadyClosed)),
      );
      return build();
    },
    seed: () => ready,
    act: (bloc) => bloc.add(const SeasonClosureEvent.confirmed()),
    expect: () => [
      ready.copyWith(status: SeasonClosureStatus.closing),
      ready.copyWith(
        failure: const InvariantViolation(InvariantCode.seasonAlreadyClosed),
      ),
    ],
  );

  blocTest<SeasonClosureBloc, SeasonClosureState>(
    'ignores a confirmation while loading',
    build: build,
    act: (bloc) => bloc.add(const SeasonClosureEvent.confirmed()),
    expect: () => <SeasonClosureState>[],
  );
}
