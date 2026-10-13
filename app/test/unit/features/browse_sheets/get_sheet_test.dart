import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/features/browse_sheets/domain/get_sheet.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
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

  GetSheet build({
    List<ExerciseDiagram> diagrams = const [],
    Future<DiagramLibrary> Function()? library,
    RulesConfig? rules,
  }) => GetSheet(
    FixtureSessionSheetRepository(catalogueFixture()),
    DomainWorld(catalogue: catalogue).catalogueRepository,
    _Diagrams(library ?? () async => DiagramLibrary(diagrams)),
    rules ?? RulesConfig(),
  );

  test(
    'reads a session with its part count and its previous session',
    () async {
      final detail = ok(await build()(SheetId('demi-bille-2')));

      expect(detail.sheet.id, SheetId('demi-bille-2'));
      expect(detail.partCount, 2);
      expect(detail.previous?.id, SheetId('demi-bille-1'));
    },
  );

  test('has no previous session for the first one of the catalogue', () async {
    final detail = ok(await build()(SheetId('posture-1')));

    expect(detail.previous, isNull);
    expect(detail.partCount, 1);
  });

  test('reads the rate of every exercise in the training catalogue', () async {
    final detail = ok(await build()(SheetId('demi-bille-1')));

    expect(detail.exerciseSpecs.keys, ['e1', 'e2']);
    expect(detail.exerciseSpecs['e1']!.rate, rate());
  });

  test('leaves out an exercise unknown to the training catalogue', () async {
    final detail = ok(
      await GetSheet(
        FixtureSessionSheetRepository(catalogueFixture()),
        DomainWorld(catalogue: buildCatalogue()).catalogueRepository,
        _Diagrams(() async => DiagramLibrary(const [])),
        RulesConfig(),
      )(SheetId('demi-bille-1')),
    );

    expect(detail.exerciseSpecs, isEmpty);
  });

  test('resolves the diagrams of the exercises by identifier', () async {
    final detail = ok(
      await build(
        diagrams: [_diagram('entrainement-p05-e1'), _diagram('autre')],
      )(SheetId('demi-bille-1')),
    );

    expect(detail.diagrams.keys, ['entrainement-p05-e1']);
    expect(detail.diagramsUnreadable, isFalse);
  });

  test('resolves the diagrams cited by `diagram_ref` illustrations', () async {
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
    final detail = ok(
      await GetSheet(
        FixtureSessionSheetRepository(sheets),
        DomainWorld(catalogue: catalogue).catalogueRepository,
        _Diagrams(() async => DiagramLibrary([_diagram('initiation-p07-e1')])),
        RulesConfig(),
      )(SheetId('demi-bille-2')),
    );

    expect(detail.diagrams.keys, contains('initiation-p07-e1'));
  });

  test(
    'computes the timing of both audiences from the configured shapes',
    () async {
      final detail = ok(await build()(SheetId('demi-bille-1')));

      expect(detail.timings[Audience.children]!.total, 90);
      expect(detail.timings[Audience.adults]!.total, 120);
    },
  );

  test('keeps the session readable when the diagrams are unreadable', () async {
    final detail = ok(
      await build(
        library: () async =>
            throw const InvariantViolation(InvariantCode.invalidDiagram),
      )(SheetId('demi-bille-1')),
    );

    expect(detail.diagramsUnreadable, isTrue);
    expect(detail.diagrams, isEmpty);
  });

  test('propagates any other failure of the diagrams', () async {
    final result = await build(
      library: () async => throw const NotFound('diagram', 'x'),
    )(SheetId('demi-bille-1'));

    expect(err(result), isA<NotFound>());
  });

  test('refuses an unknown session', () async {
    final result = await build()(SheetId('inconnue-9'));

    final failure = err(result);
    expect(failure, isA<NotFound>());
    expect((failure as NotFound).id, 'inconnue-9');
  });
}
