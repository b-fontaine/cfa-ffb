import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/plan_next_session_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlan extends Mock implements PlanSession;

void main() {
  late _MockPlan planSession;
  final date = DateTime(2026, 10, 19);
  final planned = Session(
    id: 'p1',
    title: 'Quantité demi-bille, séance 2/2',
    date: date,
    audience: Audience.children,
    groupId: const GroupId('g1'),
    sheetId: SheetId('demi-bille-2'),
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(Audience.children);
  });
  setUp(() => planSession = _MockPlan());

  void stubPlan(Future<Session> Function() answer) {
    when(
      () => planSession(
        title: any(named: 'title'),
        date: any(named: 'date'),
        audience: any(named: 'audience'),
        sheetId: any(named: 'sheetId'),
        groupId: any(named: 'groupId'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<void> plan(PlanNextSessionCubit cubit) => cubit.plan(
    title: planned.title,
    date: date,
    audience: Audience.children,
    sheetId: SheetId('demi-bille-2'),
    groupId: const GroupId('g1'),
  );

  blocTest<PlanNextSessionCubit, PlanNextSessionState>(
    'plans the session for the group, dated',
    setUp: () => stubPlan(() async => planned),
    build: () => PlanNextSessionCubit(planSession),
    act: plan,
    expect: () => [
      const PlanNextSessionState.planning(),
      PlanNextSessionState.planned(planned),
    ],
    verify: (_) => verify(
      () => planSession(
        title: 'Quantité demi-bille, séance 2/2',
        date: date,
        audience: Audience.children,
        sheetId: SheetId('demi-bille-2'),
        groupId: const GroupId('g1'),
      ),
    ).called(1),
  );

  blocTest<PlanNextSessionCubit, PlanNextSessionState>(
    'reports a date outside the season',
    setUp: () => stubPlan(
      () async =>
          throw const InvariantViolation(InvariantCode.seasonOutsidePeriod),
    ),
    build: () => PlanNextSessionCubit(planSession),
    act: plan,
    expect: () => [
      const PlanNextSessionState.planning(),
      const PlanNextSessionState.failed(
        InvariantViolation(InvariantCode.seasonOutsidePeriod),
      ),
    ],
  );

  blocTest<PlanNextSessionCubit, PlanNextSessionState>(
    'reports a blank title as a blank name',
    setUp: () => stubPlan(() async => throw const InvalidSessionTitle()),
    build: () => PlanNextSessionCubit(planSession),
    act: plan,
    expect: () => [
      const PlanNextSessionState.planning(),
      const PlanNextSessionState.failed(
        InvariantViolation(InvariantCode.blankName),
      ),
    ],
  );

  blocTest<PlanNextSessionCubit, PlanNextSessionState>(
    'ignores a second tap while planning',
    setUp: () => stubPlan(() async => planned),
    build: () => PlanNextSessionCubit(planSession),
    act: (cubit) async {
      final first = plan(cubit);
      await plan(cubit);
      await first;
    },
    expect: () => [
      const PlanNextSessionState.planning(),
      PlanNextSessionState.planned(planned),
    ],
    verify: (_) => verify(
      () => planSession(
        title: any(named: 'title'),
        date: any(named: 'date'),
        audience: any(named: 'audience'),
        sheetId: any(named: 'sheetId'),
        groupId: any(named: 'groupId'),
      ),
    ).called(1),
  );

  blocTest<PlanNextSessionCubit, PlanNextSessionState>(
    'does not plan twice once planned',
    setUp: () => stubPlan(() async => planned),
    build: () => PlanNextSessionCubit(planSession),
    act: (cubit) async {
      await plan(cubit);
      await plan(cubit);
    },
    expect: () => [
      const PlanNextSessionState.planning(),
      PlanNextSessionState.planned(planned),
    ],
  );

  blocTest<PlanNextSessionCubit, PlanNextSessionState>(
    'can retry after a failure',
    setUp: () {
      var calls = 0;
      stubPlan(() async {
        if (calls++ == 0) {
          throw const InvariantViolation(InvariantCode.unknownGroup);
        }
        return planned;
      });
    },
    build: () => PlanNextSessionCubit(planSession),
    act: (cubit) async {
      await plan(cubit);
      await plan(cubit);
    },
    expect: () => [
      const PlanNextSessionState.planning(),
      const PlanNextSessionState.failed(
        InvariantViolation(InvariantCode.unknownGroup),
      ),
      const PlanNextSessionState.planning(),
      PlanNextSessionState.planned(planned),
    ],
  );
}
