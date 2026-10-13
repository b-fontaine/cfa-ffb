import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_presentation_cubit.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/session_sheet_fixtures.dart';

class _MockResolve extends Mock implements ResolveRunPlan;

ExerciseDiagram _diagram(String id) => ExerciseDiagram(
  id: id,
  kind: DiagramKind.exercise,
  sheet: 'Fiche',
  caption: 'Légende',
  description: 'Description',
  sourceFile: 'Test.pdf',
  sourcePage: 1,
  table: const DiagramTable(balls: []),
);

/// Recall (rien à montrer), théorie avec illustration, théorie sans, exercice
/// avec schéma, jeu avec illustration, bilan.
final _link = SheetLink(
  notionOf: SheetId('bille-pleine-2'),
  rule: 'Règle.',
  note: 'Note.',
);

RunPlan _plan() {
  final sheet = buildSheet(
    theory: [
      theorySection('t1', illustrations: ['contact']),
      theorySection('t2'),
    ],
    illustrations: [contactIllustration('contact'), contactIllustration('jeu')],
    game: sheetGame(setupIllustration: 'jeu', link: _link),
  );
  return RunPlan(
    sheet: sheet,
    audience: Audience.children,
    partCount: 2,
    timing: sheetTiming(
      sheet,
      audience: Audience.children,
      shapes: RulesConfig().shapes,
    ),
    steps: const [
      RunStep(
        kind: RunStepKind.recall,
        phase: SessionPhase.welcome,
        minutes: 10,
      ),
      RunStep(
        kind: RunStepKind.theory,
        phase: SessionPhase.notionAndInitiation,
        minutes: 10,
        elementId: 't1',
      ),
      RunStep(
        kind: RunStepKind.theory,
        phase: SessionPhase.notionAndInitiation,
        minutes: 10,
        elementId: 't2',
      ),
      RunStep(
        kind: RunStepKind.exercise,
        phase: SessionPhase.training,
        minutes: 35,
        elementId: 'e1',
      ),
      RunStep(kind: RunStepKind.game, phase: SessionPhase.game, minutes: 20),
      RunStep(kind: RunStepKind.review, phase: SessionPhase.review, minutes: 5),
    ],
    passesRequired: 5,
    diagrams: {'entrainement-p05-e1': _diagram('entrainement-p05-e1')},
  );
}

void main() {
  late _MockResolve resolve;
  final id = SheetId('demi-bille-1');

  setUpAll(() => registerFallbackValue(SheetId('x-1')));
  setUp(() {
    resolve = _MockResolve();
    when(
      () => resolve(
        any(),
        audience: any(named: 'audience'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async => Ok(_plan()));
  });

  Future<RunPresentationCubit> started({int step = 1}) async {
    final cubit = RunPresentationCubit(resolve);
    await cubit.started(sheetId: id, step: step);
    return cubit;
  }

  test('resolves the plan for the audience and the session', () async {
    final cubit = RunPresentationCubit(resolve);

    await cubit.started(
      sheetId: id,
      audience: Audience.adults,
      sessionId: 'p1',
      step: 3,
    );

    verify(() => resolve(id, audience: Audience.adults, sessionId: 'p1'))
        .called(1);
    expect(cubit.state.status, PresentationStatus.ready);
    expect(cubit.state.step, 3);
  });

  test('opens on the last step to show when the address is past it', () async {
    final cubit = await started(step: 99);

    expect(cubit.state.step, 4);
  });

  test('opens on the next step to show when the asked one has none', () async {
    expect((await started(step: 0)).state.step, 1);
    expect((await started(step: 2)).state.step, 3);
    expect((await started(step: 5)).state.step, 4);
  });

  test('keeps the asked step when it has something to show', () async {
    expect((await started(step: 3)).state.step, 3);
  });

  test('goes to the next step that has something to show', () async {
    final cubit = await started();

    cubit.next();

    expect(cubit.state.step, 3);
    cubit.next();
    expect(cubit.state.step, 4);
  });

  test('stays on the last step that has something to show', () async {
    final cubit = await started(step: 4);

    cubit.next();

    expect(cubit.state.step, 4);
  });

  test('goes back to the previous step that has something to show', () async {
    final cubit = await started(step: 3);

    cubit.previous();

    expect(cubit.state.step, 1);
  });

  test('stays on the first step that has something to show', () async {
    final cubit = await started();

    cubit.previous();

    expect(cubit.state.step, 1);
  });

  test('reports an unknown session as not found', () async {
    when(
      () => resolve(
        any(),
        audience: any(named: 'audience'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async => const Err(NotFound('sheet', 'x')));

    final cubit = await started();

    expect(cubit.state.status, PresentationStatus.notFound);
  });

  test('reports a failure', () async {
    when(
      () => resolve(
        any(),
        audience: any(named: 'audience'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer(
      (_) async => const Err(InvariantViolation(InvariantCode.invalidSheet)),
    );

    final cubit = await started();

    expect(cubit.state.status, PresentationStatus.failure);
    expect(cubit.state.failure, isA<InvariantViolation>());
  });

  test('ignores moves before the plan is ready', () {
    final cubit = RunPresentationCubit(resolve)
      ..next()
      ..previous();

    expect(cubit.state.status, PresentationStatus.loading);
  });

  group('retry', () {
    test('asks again with the same arguments after a failure', () async {
      var attempts = 0;
      when(
        () => resolve(
          any(),
          audience: any(named: 'audience'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        return attempts == 1
            ? const Err(InvariantViolation(InvariantCode.invalidSheet))
            : Ok(_plan());
      });
      final cubit = RunPresentationCubit(resolve);
      await cubit.started(
        sheetId: id,
        audience: Audience.adults,
        sessionId: 'p1',
        step: 3,
      );
      expect(cubit.state.status, PresentationStatus.failure);

      await cubit.retry();

      verify(() => resolve(id, audience: Audience.adults, sessionId: 'p1'))
          .called(2);
      expect(cubit.state.status, PresentationStatus.ready);
      expect(cubit.state.step, 3);
    });

    test('does nothing before any opening', () async {
      final cubit = RunPresentationCubit(resolve);

      await cubit.retry();

      verifyNever(
        () => resolve(
          any(),
          audience: any(named: 'audience'),
          sessionId: any(named: 'sessionId'),
        ),
      );
      expect(cubit.state.status, PresentationStatus.loading);
    });
  });
}
