import 'dart:async';

import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/closure_plan.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/features/close_season/domain/prepare_season_closure.dart';
import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/season_closure_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixed_clock.dart';
import '../../../../support/fixtures.dart';

class _MockPrepare extends Mock implements PrepareSeasonClosure;

class _MockClosing extends Mock implements SeasonClosing;

void main() {
  late _MockPrepare prepare;
  late _MockClosing closing;
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
    closing = _MockClosing();
    when(() => closing.synchronized).thenReturn(false);
  });

  SeasonClosureBloc build() => SeasonClosureBloc(
    prepare,
    closing,
    FixedClock(DateTime(2026, 10, 12, 9)),
  );

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
      // Sur l'appareil, pas d'invitation : rien à compter.
      verifyNever(() => closing.invitationsToPurge());
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
        () => closing.close(
          seasonId: seasonId,
          closedOn: day(12),
          erase: {hugo},
          prepareNext: any(named: 'prepareNext'),
          dropPlanned: any(named: 'dropPlanned'),
          shouldStop: any(named: 'shouldStop'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const Ok(
          ClosureOutcome(
            status: OperationRunStatus.completed,
            doneLots: 1,
            totalLots: 1,
            result: ClosureResult(
              erased: 1,
              kept: 1,
              groupsPrepared: 1,
              plannedDropped: 2,
            ),
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
        done: 1,
        total: 1,
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
        () => closing.close(
          seasonId: seasonId,
          closedOn: day(12),
          erase: {hugo},
          prepareNext: any(named: 'prepareNext'),
          dropPlanned: any(named: 'dropPlanned'),
          shouldStop: any(named: 'shouldStop'),
          onProgress: any(named: 'onProgress'),
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
  group('club synchronisé (lots reprenables)', () {
    final terms = ClosureTerms(
      seasonId: seasonId,
      closedOn: day(12),
      prepareNext: true,
      dropPlanned: true,
    );
    final synced = ready.copyWith(synchronized: true);

    void stubClose(ClosureOutcome outcome) {
      when(
        () => closing.close(
          seasonId: seasonId,
          closedOn: day(12),
          erase: {hugo},
          prepareNext: any(named: 'prepareNext'),
          dropPlanned: any(named: 'dropPlanned'),
          shouldStop: any(named: 'shouldStop'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => Ok(outcome));
    }

    setUp(() {
      when(() => closing.synchronized).thenReturn(true);
      when(() => closing.pending()).thenAnswer((_) async => const Ok(null));
      when(() => closing.invitationsToPurge())
          .thenAnswer((_) async => const Ok(3));
    });

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'the preview counts the used or expired invitations the closure will '
      'delete',
      build: () {
        when(() => prepare(seasonId: seasonId, today: day(12)))
            .thenAnswer((_) async => Ok(plan));
        return build();
      },
      act: (bloc) =>
          bloc.add(const SeasonClosureEvent.started(seasonId: seasonId)),
      expect: () => [
        const SeasonClosureState(synchronized: true),
        synced.copyWith(invitationsToPurge: 3),
      ],
    );

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'invitations that cannot be counted give no figure and never block the '
      'closure',
      build: () {
        when(() => prepare(seasonId: seasonId, today: day(12)))
            .thenAnswer((_) async => Ok(plan));
        when(() => closing.invitationsToPurge()).thenAnswer(
          (_) async =>
              const Err(ServiceFailure(ServiceFailureCode.denied, 'rules')),
        );
        return build();
      },
      act: (bloc) =>
          bloc.add(const SeasonClosureEvent.started(seasonId: seasonId)),
      expect: () => [const SeasonClosureState(synchronized: true), synced],
    );

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'a closure of this season already started is offered for resumption, '
      'before anything else',
      build: () {
        when(() => closing.pending()).thenAnswer((_) async => Ok(terms));
        return build();
      },
      act: (bloc) =>
          bloc.add(const SeasonClosureEvent.started(seasonId: seasonId)),
      expect: () => [
        const SeasonClosureState(synchronized: true),
        SeasonClosureState(
          status: SeasonClosureStatus.resumable,
          synchronized: true,
          pending: terms,
        ),
      ],
      verify: (_) => verifyNever(
        () => prepare(
          seasonId: any(named: 'seasonId'),
          today: any(named: 'today'),
        ),
      ),
    );

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'an unreadable marker is an error to retry, never a new closure offered '
      'with other choices',
      build: () {
        when(() => closing.pending()).thenAnswer(
          (_) async =>
              const Err(ServiceFailure(ServiceFailureCode.unavailable, 'off')),
        );
        return build();
      },
      act: (bloc) =>
          bloc.add(const SeasonClosureEvent.started(seasonId: seasonId)),
      expect: () => [
        const SeasonClosureState(synchronized: true),
        const SeasonClosureState(
          status: SeasonClosureStatus.failure,
          synchronized: true,
          failure: ServiceFailure(ServiceFailureCode.unavailable, 'off'),
        ),
      ],
      verify: (_) => verifyNever(
        () => prepare(
          seasonId: any(named: 'seasonId'),
          today: any(named: 'today'),
        ),
      ),
    );

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'a closure of another season does not hide the assistant',
      build: () {
        when(() => closing.pending()).thenAnswer(
          (_) async => Ok(
            ClosureTerms(
              seasonId: const SeasonId('other'),
              closedOn: day(12),
              prepareNext: true,
              dropPlanned: true,
            ),
          ),
        );
        when(() => prepare(seasonId: seasonId, today: day(12)))
            .thenAnswer((_) async => Ok(plan));
        return build();
      },
      act: (bloc) =>
          bloc.add(const SeasonClosureEvent.started(seasonId: seasonId)),
      expect: () => [
        const SeasonClosureState(synchronized: true),
        synced.copyWith(invitationsToPurge: 3),
      ],
    );

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'resuming asks nothing again and finishes without a report',
      build: () {
        when(
          () => closing.resume(
            terms,
            shouldStop: any(named: 'shouldStop'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => const Ok(
            ClosureOutcome(
              status: OperationRunStatus.completed,
              doneLots: 7,
              totalLots: 7,
            ),
          ),
        );
        return build();
      },
      seed: () => SeasonClosureState(
        status: SeasonClosureStatus.resumable,
        synchronized: true,
        pending: terms,
      ),
      act: (bloc) => bloc.add(const SeasonClosureEvent.resumed()),
      expect: () => [
        SeasonClosureState(
          status: SeasonClosureStatus.closing,
          synchronized: true,
          pending: terms,
        ),
        const SeasonClosureState(
          status: SeasonClosureStatus.closed,
          synchronized: true,
          done: 7,
          total: 7,
        ),
      ],
    );

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'a lost connection leaves the closure to resume with its terms',
      build: () {
        stubClose(
          const ClosureOutcome(
            status: OperationRunStatus.interrupted,
            doneLots: 3,
            totalLots: 9,
            failure: ServiceFailure(ServiceFailureCode.unavailable),
          ),
        );
        return build();
      },
      seed: () => synced,
      act: (bloc) => bloc.add(const SeasonClosureEvent.confirmed()),
      skip: 1,
      expect: () => [
        synced.copyWith(
          status: SeasonClosureStatus.interrupted,
          pending: terms,
          done: 3,
          total: 9,
          failure: const ServiceFailure(ServiceFailureCode.unavailable),
        ),
      ],
    );

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'the daily write ceiling pauses the closure until another day',
      build: () {
        stubClose(
          const ClosureOutcome(
            status: OperationRunStatus.paused,
            doneLots: 4,
            totalLots: 11,
          ),
        );
        return build();
      },
      seed: () => synced,
      act: (bloc) => bloc.add(const SeasonClosureEvent.confirmed()),
      skip: 1,
      expect: () => [
        synced.copyWith(
          status: SeasonClosureStatus.paused,
          pending: terms,
          done: 4,
          total: 11,
        ),
      ],
    );

    blocTest<SeasonClosureBloc, SeasonClosureState>(
      'more students to erase than a first lot can declare is refused '
      'before any write',
      build: build,
      seed: () => synced.copyWith(
        choices: {
          for (var i = 0; i < 391; i++) StudentId('s$i'): ClosureChoice.erase,
        },
      ),
      act: (bloc) => bloc.add(const SeasonClosureEvent.confirmed()),
      expect: () => [
        isA<SeasonClosureState>()
            .having((s) => s.status, 'status', SeasonClosureStatus.ready)
            .having(
              (s) => s.failure,
              'failure',
              isA<InvariantViolation>().having(
                (f) => f.code,
                'code',
                InvariantCode.tooManyToErase,
              ),
            ),
      ],
      verify: (_) => verifyNever(
        () => closing.close(
          seasonId: any(named: 'seasonId'),
          closedOn: any(named: 'closedOn'),
          erase: any(named: 'erase'),
        ),
      ),
    );

    test('a stop request is read between two lots', () async {
      final release = Completer<void>();
      bool Function()? stop;
      when(
        () => closing.close(
          seasonId: seasonId,
          closedOn: day(12),
          erase: {hugo},
          prepareNext: any(named: 'prepareNext'),
          dropPlanned: any(named: 'dropPlanned'),
          shouldStop: any(named: 'shouldStop'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        stop = invocation.namedArguments[#shouldStop] as bool Function()?;
        await release.future;
        return Ok(
          ClosureOutcome(
            status: stop!()
                ? OperationRunStatus.cancelled
                : OperationRunStatus.completed,
            doneLots: 2,
            totalLots: 9,
          ),
        );
      });
      final bloc = build()
        ..emit(synced)
        ..add(const SeasonClosureEvent.confirmed());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SeasonClosureEvent.stopRequested());
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, SeasonClosureStatus.stopped);
      expect(bloc.state.pending, terms);
      await bloc.close();
    });
  });
}
