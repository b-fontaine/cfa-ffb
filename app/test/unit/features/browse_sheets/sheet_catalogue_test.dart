import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_sources.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/session_sheet_fixtures.dart';

void main() {
  late SheetCatalogue catalogue;

  setUp(() async {
    catalogue = ok(
      await ListSheets(FixtureSessionSheetRepository(catalogueFixture()))(),
    );
  });

  group('filtered', () {
    test('keeps only the sessions with [Prop] content', () {
      final reduced = catalogue.filtered(SheetReviewFilter.toReview);

      expect(reduced.sheetCount, 2);
      expect(reduced.groups.expand((g) => g.sheets).map((s) => s.id.value), [
        'posture-1',
        'quart-1',
      ]);
    });

    test('drops the techniques with nothing to validate', () {
      final reduced = catalogue.filtered(SheetReviewFilter.toReview);

      expect(reduced.groups.map((g) => g.technique), ['posture', 'quart']);
    });

    test('keeps everything without a filter', () {
      final all = catalogue.filtered(SheetReviewFilter.none);

      expect(all.sheetCount, 4);
    });

    test('keeps only the sessions whose game is to validate', () {
      final games = catalogue.filtered(SheetReviewFilter.games);

      expect(games.groups.expand((g) => g.sheets).map((s) => s.id.value), [
        'quart-1',
      ]);
    });

    test('keeps the rank and the part count of the whole technique', () {
      final quart = catalogue.filtered(SheetReviewFilter.toReview).groups.last;

      expect(quart.rank, 3);
      expect(quart.partCount, 1);
    });
  });

  group('sourcedProvenances', () {
    test('lists the real sources of a session, never [Prop]', () {
      final sheet = catalogue.groups[1].sheets.first;

      expect(sourcedProvenances(sheet), {Provenance.s});
    });

    test('drops [Prop] and keeps the hierarchy order', () {
      final adapted = catalogue.groups.last.sheets.single;

      expect(sourcedProvenances(adapted), {Provenance.s});
      expect(sourcedProvenances(adapted), isNot(contains(Provenance.prop)));
    });

    test('is empty when everything is a proposal', () {
      final sheet = buildSheet(
        recall: const SheetRecall(
          points: ['Un point.'],
          ask: 'Question ?',
          answer: 'Réponse.',
          src: Provenance.prop,
        ),
        theory: [theorySection('t', src: Provenance.prop)],
        exercises: [
          sheetExercise('e1', 1, src: Provenance.prop),
          sheetExercise('e2', 2, src: Provenance.prop),
        ],
        game: sheetGame(
          src: Provenance.prop,
          adapted: true,
          link: SheetLink(
            notionOf: SheetId('bille-pleine-2'),
            rule: 'Règle.',
            note: 'Note.',
          ),
        ),
      );

      expect(sourcedProvenances(sheet), isEmpty);
    });

    test('lists every source in the order of the hierarchy', () {
      final sheet = buildSheet(
        theory: [
          theorySection('t1', src: Provenance.web),
          theorySection('t2', src: Provenance.ffb),
        ],
      );

      expect(sourcedProvenances(sheet), [
        Provenance.s,
        Provenance.ffb,
        Provenance.web,
      ]);
    });
  });
}
