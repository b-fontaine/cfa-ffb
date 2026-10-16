import 'package:billard_cfa/entities/session_sheet/data/asset_session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/needs_review.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theme.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_row.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/session_sheet_fixtures.dart';

SheetLink _link() => SheetLink(
  notionOf: SheetId('bille-pleine-2'),
  rule: 'Règle.',
  note: 'Note.',
);

void main() {
  test('the row title is the evocative name, the technique is apart', () {
    final row = sheetRowOf(buildSheet(part: 2), partCount: 3);

    expect(row.name, 'Le partage');
    expect(row.technique, 'Quantité demi-bille');
    expect(row.part, 2);
    expect(row.partCount, 3);
    expect(row.id.value, 'demi-bille-2');
  });

  test('a blank name is reported as missing, never as an empty title', () {
    final sheet = buildSheet().copyWith(
      theme: const SheetTheme(name: '   ', pitch: 'Un gâteau.'),
    );

    final row = sheetRowOf(sheet, partCount: 1);

    expect(row.hasName, isFalse);
    expect(row.name, isEmpty);
  });

  test('a sourced sheet has no point to validate and no minor proposal', () {
    final row = sheetRowOf(buildSheet(previous: null, order: 1), partCount: 1);

    expect(row.reviewPoints, 0);
    expect(row.reviewReasons, isEmpty);
    expect(row.minorReasons, isEmpty);
  });

  test('one badge counts the content types to validate, in a fixed order', () {
    final sheet = buildSheet(
      exercises: [sheetExercise('e1', 1, src: Provenance.prop)],
      game: sheetGame(adapted: true, src: Provenance.prop, link: _link()),
      recall: const SheetRecall(
        points: ['Un.', 'Deux.'],
        ask: 'Q ?',
        answer: 'R.',
        src: Provenance.prop,
      ),
    );

    final row = sheetRowOf(sheet, partCount: 1);

    expect(row.reviewPoints, 3);
    expect(row.reviewReasons, [
      ReviewReason.game,
      ReviewReason.exercise,
      ReviewReason.recall,
    ]);
  });

  test('minor proposals are listed apart and never counted', () {
    final sheet = buildSheet(
      game: sheetGame(
        link: SheetLink(
          notionOf: SheetId('bille-pleine-2'),
          rule: 'Règle.',
          note: 'Note.',
        ),
      ),
      theory: [theorySection('t1', src: Provenance.prop)],
    );

    final row = sheetRowOf(sheet, partCount: 1);

    expect(row.reviewPoints, 0);
    expect(row.minorReasons, [ReviewReason.gameLink, ReviewReason.theory]);
  });

  test('a technique group exposes one row per sheet with its part count', () {
    final group = TechniqueGroup(
      rank: 2,
      technique: 'demi-bille',
      title: 'Quantité demi-bille',
      partCount: 2,
      sheets: [buildSheet(), buildSheet(part: 2)],
    );

    expect(group.rows.map((r) => r.part), [1, 2]);
    expect(group.rows.every((r) => r.partCount == 2), isTrue);
  });

  test('every real sheet has an evocative name and badge = filter', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sheets = await AssetSessionSheetRepository.fromBundle().getAll();

    final rows = [for (final s in sheets) sheetRowOf(s, partCount: 1)];

    expect(rows.every((r) => r.hasName), isTrue);
    expect(rows.where((r) => r.reviewPoints > 0), hasLength(18));
  });
}
