import 'dart:io';

import 'package:billard_cfa/entities/session_sheet/data/session_sheet_yaml_parser.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/ghost_ball_geometry.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/fiches/context.dart';
import '../../tool/fiches/directory.dart';
import '../../tool/fiches/session_rules.dart';

// Contrat sur les vrais fichiers de `assets/fiches/` (copie de
// `docs/knowledge/05-seances/catalogue/`) : pour chaque séance présente,
// V12 (minutage) et V17 (géométrie) qui lisent du code, et les autres règles
// de `tool/fiches` rejouées sur le même fichier.

const _assetsDir = 'assets/fiches';

/// Identifiants figés des 28 séances, dans l'ordre du catalogue (FORMAT § 1.3).
/// Une séance planifiée peut les référencer : ils ne changent jamais.
const _frozenIds = [
  'posture-1',
  'posture-2',
  'puissance-1',
  'puissance-2',
  'bille-fantome-1',
  'bille-pleine-1',
  'bille-pleine-2',
  'demi-bille-1',
  'demi-bille-2',
  'trois-quarts-1',
  'trois-quarts-2',
  'quart-1',
  'finesse-1',
  'rebond-bande-1',
  'rebond-bande-2',
  'rejet-naturel-1',
  'rejet-naturel-2',
  'coule-1',
  'coule-2',
  'coule-3',
  'carreau-1',
  'carreau-2',
  'angle-droit-1',
  'angle-droit-2',
  'retro-1',
  'retro-2',
  'retro-3',
  'retro-4',
];

/// `true` depuis la fin du lot L7 (les 28 séances écrites) : la liste des
/// fichiers est exactement celle des identifiants figés.
const _catalogueComplete = true;

void main() {
  final files =
      Directory(_assetsDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final shapes = RulesConfig().shapes;
  final minDistinct = RulesConfig().minDistinctExercises;

  late FichesContext context;
  late Map<String, Map<String, Object?>> siblings;

  setUpAll(() {
    context = FichesContext.load('..');
    siblings = loadSiblings(_assetsDir);
  });

  group('the pilot sheet timing', () {
    late SessionSheet pilot;

    setUpAll(() {
      pilot = parseSessionSheet(
        File('$_assetsDir/08-demi-bille-1.yaml').readAsStringSync(),
      );
    });

    // Valeurs écrites à la main : FORMAT § 9, tableau « Minutage calculé ».
    test('gives the written children minutes', () {
      final timing = sheetTiming(
        pilot,
        audience: Audience.children,
        shapes: shapes,
      );

      expect(timing.recall, 10);
      expect(timing.theory, {'tangente': 7, 'mot-tangente': 2, 'comparer': 4});
      expect(timing.initiation, {'ini-7': 7});
      expect(timing.exercises, {'e1': 17, 'e2': 9});
      expect(timing.recallExercise, 9);
      expect(timing.game, 20);
      expect(timing.review, 5);
    });

    test('gives the written adults minutes', () {
      final timing = sheetTiming(
        pilot,
        audience: Audience.adults,
        shapes: shapes,
      );

      expect(timing.recall, 10);
      expect(timing.theory, {'tangente': 8, 'comparer': 5, 'fantome': 5});
      expect(timing.initiation, {'ini-7': 7});
      expect(timing.exercises, {'e1': 17, 'e2': 17});
      expect(timing.recallExercise, 16);
      expect(timing.game, 25);
      expect(timing.review, 10);
    });
  });

  group('the catalogue of sheets', () {
    test('contains at least the pilot sheet', () {
      expect(
        files.map((f) => f.path.split('/').last),
        contains('08-demi-bille-1.yaml'),
      );
    });

    test('uses only the frozen identifiers, in the frozen order', () {
      final sheets = [
        for (final f in files) parseSessionSheet(f.readAsStringSync()),
      ];

      for (final sheet in sheets) {
        final index = _frozenIds.indexOf(sheet.id.value);
        expect(index, greaterThanOrEqualTo(0), reason: '${sheet.id} inconnu');
        expect(sheet.order, index + 1, reason: '${sheet.id} : order');
        expect(
          sheet.previous?.value,
          index == 0 ? isNull : _frozenIds[index - 1],
          reason: '${sheet.id} : previous (chaîne sans cycle)',
        );
      }
      expect(sheets.map((s) => s.id).toSet(), hasLength(sheets.length));
    });

    test('has the 28 sheets once the writing is complete', () {
      final ids = [
        for (final f in files) parseSessionSheet(f.readAsStringSync()).id.value,
      ];

      if (_catalogueComplete) {
        expect(ids, _frozenIds);
      } else {
        expect(ids.length, lessThanOrEqualTo(_frozenIds.length));
        expect(_frozenIds, hasLength(28));
      }
    });
  });

  for (final file in files) {
    final name = file.path.split('/').last;

    group('sheet $name', () {
      late SessionSheet sheet;
      late String text;

      setUpAll(() {
        text = file.readAsStringSync();
        sheet = parseSessionSheet(text);
      });

      test('is named NN-<id>.yaml with NN = order', () {
        final prefix = sheet.order.toString().padLeft(2, '0');

        expect(name, '$prefix-${sheet.id}.yaml');
      });

      test('passes the rules V1 to V22 of tool/fiches', () {
        final errors = validateSession(
          text,
          fileName: name,
          context: context,
          siblings: siblings,
        );

        expect(errors, isEmpty);
      });

      for (final audience in Audience.values) {
        test('V12: ${audience.name} timing sums to the session duration', () {
          final timing = sheetTiming(sheet, audience: audience, shapes: shapes);

          expect(timing.total, audience.sessionDuration.inMinutes);
        });

        test('V12: ${audience.name} elements each get at least 1 minute', () {
          final timing = sheetTiming(sheet, audience: audience, shapes: shapes);
          final all = [
            timing.recall,
            ...timing.theory.values,
            ...timing.initiation.values,
            ...timing.exercises.values,
            timing.game,
            timing.review,
          ];

          expect(all, everyElement(greaterThanOrEqualTo(1)));
        });

        test('V11: ${audience.name} sees enough distinct exercises', () {
          final shown = sheet.exercises.where(
            (e) => e.weight.isShownFor(audience),
          );

          expect(shown.length, greaterThanOrEqualTo(minDistinct));
        });
      }

      test('V17: every ghost_aim is geometrically consistent', () {
        final aims = sheet.illustrations.whereType<GhostAimIllustration>();

        for (final aim in aims) {
          for (final point in [aim.cue, aim.object]) {
            expect(point.x, inInclusiveRange(0, 8), reason: '${aim.id} : x');
            expect(point.y, inInclusiveRange(0, 4), reason: '${aim.id} : y');
          }
          final gap = ghostAimDeviation(
            cue: aim.cue,
            object: aim.object,
            pocket: aim.pocket,
            fraction: aim.fraction,
          );

          expect(
            gap,
            lessThanOrEqualTo(ghostAimTolerance()),
            reason: '${aim.id} : ${aim.fraction.name}, écart $gap',
          );
          // Marge de 0,02 s sous la tolérance (0,07 s) : 0,05 s au plus.
          expect(
            gap,
            lessThanOrEqualTo(0.05 * BallSizes.standard.ghostDistance),
            reason: '${aim.id} : marge, écart $gap',
          );
        }
      });
    });
  }
}
