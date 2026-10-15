import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/features/run_sheet/domain/load_validated_exercises.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

class _Diagrams implements DiagramRepository {
  _Diagrams(this._load);

  final Future<DiagramLibrary> Function() _load;

  @override
  Future<DiagramLibrary> load() => _load();
}

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

void main() {
  final catalogue = buildCatalogue([
    block('posture', 1),
    block('demi-bille', 2, exercises: 4),
    block('quart-finesses', 3),
  ]);

  late InMemorySessionRepository sessions;

  setUp(() => sessions = InMemorySessionRepository());

  LoadValidatedExercises validated(DomainWorld world) => LoadValidatedExercises(
    world.students,
    world.groups,
    world.attempts,
    world.acquisitions,
    RulesStore(world.config),
  );

  ResolveRunPlan build({
    List<ExerciseDiagram> diagrams = const [],
    Future<DiagramLibrary> Function()? library,
    RulesConfig? rules,
    DomainWorld? world,
  }) {
    final domain = world ?? DomainWorld(catalogue: catalogue, config: rules);
    return ResolveRunPlan(
      FixtureSessionSheetRepository(catalogueFixture()),
      sessions,
      domain.catalogueRepository,
      _Diagrams(library ?? () async => DiagramLibrary(diagrams)),
      RulesStore(rules ?? RulesConfig()),
      validated(domain),
    );
  }

  test('lists the steps in the teaching order for the audience', () async {
    final plan = ok(
      await build()(SheetId('demi-bille-1'), audience: Audience.children),
    );

    expect(plan.steps.map((s) => s.kind), [
      RunStepKind.recall,
      RunStepKind.theory,
      RunStepKind.exercise,
      RunStepKind.exercise,
      RunStepKind.recallExercise,
      RunStepKind.game,
      RunStepKind.review,
    ]);
    expect(plan.steps.map((s) => s.phase), [
      SessionPhase.welcome,
      SessionPhase.notionAndInitiation,
      SessionPhase.training,
      SessionPhase.training,
      SessionPhase.training,
      SessionPhase.game,
      SessionPhase.review,
    ]);
    expect(plan.steps[1].elementId, 't1');
    expect(plan.steps[2].elementId, 'e1');
  });

  test('leaves out the elements without a weight for the audience', () async {
    final sheets = [
      for (final s in catalogueFixture())
        if (s.id.value == 'demi-bille-1')
          s.copyWith(
            theorySections: [
              ...s.theorySections,
              theorySection('adultes', weight: AudienceWeight(adults: 2)),
            ],
          )
        else
          s,
    ];
    final world = DomainWorld(catalogue: catalogue);
    final resolve = ResolveRunPlan(
      FixtureSessionSheetRepository(sheets),
      sessions,
      world.catalogueRepository,
      _Diagrams(() async => DiagramLibrary(const [])),
      RulesStore(RulesConfig()),
      validated(world),
    );

    final children = ok(
      await resolve(SheetId('demi-bille-1'), audience: Audience.children),
    );
    final adults = ok(
      await resolve(SheetId('demi-bille-1'), audience: Audience.adults),
    );

    expect(children.steps.map((s) => s.elementId), isNot(contains('adultes')));
    expect(adults.steps.map((s) => s.elementId), contains('adultes'));
  });

  test('computes the minutes of each step and of each phase', () async {
    final plan = ok(
      await build()(SheetId('demi-bille-1'), audience: Audience.adults),
    );

    expect(plan.timing.total, 120);
    expect(plan.steps.fold(0, (sum, s) => sum + s.minutes), 120);
    expect(plan.steps.first.minutes, plan.timing.phaseMinutes.values.first);
  });

  test(
    'takes the audience of the planned session when none is given',
    () async {
      await sessions.add(
        Session(
          id: 'p1',
          title: 'Cours',
          date: day(12),
          audience: Audience.adults,
        ),
      );

      final plan = ok(await build()(SheetId('demi-bille-1'), sessionId: 'p1'));

      expect(plan.audience, Audience.adults);
    },
  );

  test('exposes the planned session it was launched from', () async {
    await sessions.add(
      Session(
        id: 'p1',
        title: 'Cours',
        date: day(19),
        audience: Audience.adults,
        groupId: const GroupId('g1'),
      ),
    );

    final launched = ok(
      await build()(SheetId('demi-bille-1'), sessionId: 'p1'),
    );
    final free = ok(await build()(SheetId('demi-bille-1')));
    final gone = ok(await build()(SheetId('demi-bille-1'), sessionId: 'p9'));

    expect(launched.planned?.groupId, const GroupId('g1'));
    expect(launched.planned?.date, day(19));
    expect(free.planned, isNull);
    expect(gone.planned, isNull);
  });

  test('prefers the requested audience to the planned session', () async {
    await sessions.add(
      Session(
        id: 'p1',
        title: 'Cours',
        date: day(12),
        audience: Audience.adults,
      ),
    );

    final plan = ok(
      await build()(
        SheetId('demi-bille-1'),
        audience: Audience.children,
        sessionId: 'p1',
      ),
    );

    expect(plan.audience, Audience.children);
  });

  test('falls back on the children for an unknown planned session', () async {
    final plan = ok(await build()(SheetId('demi-bille-1'), sessionId: 'zz'));

    expect(plan.audience, Audience.children);
  });

  test('falls back on the children without audience nor session', () async {
    final plan = ok(await build()(SheetId('demi-bille-1')));

    expect(plan.audience, Audience.children);
  });

  test('reads the part counts and the previous session', () async {
    final plan = ok(await build()(SheetId('demi-bille-2')));

    expect(plan.partCount, 2);
    expect(plan.previous?.id, SheetId('demi-bille-1'));
    expect(plan.previousPartCount, 2);
  });

  test('has neither previous session nor recall block for the first', () async {
    final plan = ok(await build()(SheetId('posture-1')));

    expect(plan.previous, isNull);
    expect(plan.previousPartCount, isNull);
    expect(plan.recallBlockId, isNull);
  });

  test('gives the results recall block of the previous technique', () async {
    final plan = ok(await build()(SheetId('demi-bille-2')));

    expect(plan.recallBlockId, 'posture');
  });

  test('reads the rate and the title of the training block', () async {
    final plan = ok(await build()(SheetId('demi-bille-1')));

    expect(plan.exerciseSpecs.keys, ['e1', 'e2']);
    expect(plan.exerciseSpecs['e1']!.rate, rate());
    expect(plan.blockTitle, 'Bloc demi-bille');
    expect(plan.passesRequired, 5);
  });

  test('takes the passes required from the configured rules', () async {
    final plan = ok(
      await build(rules: RulesConfig(passesRequired: 3))(
        SheetId('demi-bille-1'),
      ),
    );

    expect(plan.passesRequired, 3);
  });

  test('reads the rules at each call, not at construction', () async {
    final store = RulesStore(RulesConfig());
    final domain = DomainWorld(catalogue: catalogue);
    final resolve = ResolveRunPlan(
      FixtureSessionSheetRepository(catalogueFixture()),
      sessions,
      domain.catalogueRepository,
      _Diagrams(() async => DiagramLibrary(const [])),
      store,
      validated(domain),
    );
    final before = ok(await resolve(SheetId('demi-bille-1')));

    store.current = RulesConfig(passesRequired: 2);
    final after = ok(await resolve(SheetId('demi-bille-1')));

    expect([before.passesRequired, after.passesRequired], [5, 2]);
  });

  test('resolves the diagrams of the exercises and the cited ones', () async {
    final sheets = [
      for (final s in catalogueFixture())
        if (s.id.value == 'demi-bille-1')
          s.copyWith(
            illustrations: [
              const Illustration.diagramRef(
                id: 'schema',
                caption: 'Légende',
                alt: 'Alt',
                diagramId: 'initiation-p07-e1',
              ),
            ],
          )
        else
          s,
    ];
    final plan = ok(
      await ResolveRunPlan(
        FixtureSessionSheetRepository(sheets),
        sessions,
        DomainWorld(catalogue: catalogue).catalogueRepository,
        _Diagrams(
          () async => DiagramLibrary([
            _diagram('entrainement-p05-e1'),
            _diagram('initiation-p07-e1'),
            _diagram('autre'),
          ]),
        ),
        RulesStore(RulesConfig()),
        validated(DomainWorld(catalogue: catalogue)),
      )(SheetId('demi-bille-1')),
    );

    expect(plan.diagrams.keys, {'entrainement-p05-e1', 'initiation-p07-e1'});
    expect(plan.diagramsUnreadable, isFalse);
  });

  test('stays readable when the diagrams cannot be read', () async {
    final plan = ok(
      await build(
        library: () async =>
            throw const InvariantViolation(InvariantCode.invalidDiagram),
      )(SheetId('demi-bille-1')),
    );

    expect(plan.diagramsUnreadable, isTrue);
    expect(plan.diagrams, isEmpty);
  });

  test('reports an unknown session as not found', () async {
    final failure = err(await build()(SheetId('inconnue-9')));

    expect(failure, isA<NotFound>());
  });

  test('does not hide a real failure of the diagram library', () async {
    final failure = err(
      await build(
        library: () async =>
            throw const InvariantViolation(InvariantCode.invalidCatalogue),
      )(SheetId('demi-bille-1')),
    );

    expect(failure, isA<InvariantViolation>());
  });
}
