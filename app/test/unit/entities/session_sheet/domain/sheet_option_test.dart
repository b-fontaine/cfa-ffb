import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/session_sheet_fixtures.dart';

void main() {
  final sheets = catalogueFixture().reversed.toList();

  test('lists the sessions in teaching order with technique and parts', () {
    final options = sheetOptionsOf(sheets);

    expect(options.map((o) => o.id.value), [
      'posture-1',
      'demi-bille-1',
      'demi-bille-2',
      'quart-1',
    ]);
    expect(options.map((o) => o.techniqueRank), [1, 2, 2, 3]);
    expect(options.map((o) => o.part), [1, 1, 2, 1]);
    expect(options.map((o) => o.partCount), [1, 2, 2, 1]);
    expect(options[1].technique, 'demi-bille');
    expect(options[1].title, 'Quantité demi-bille');
  });

  test('carries the title of each exercise of the session by reference', () {
    final options = sheetOptionsOf(sheets);

    expect(options[2].exerciseTitles, {
      ExerciseRef(blockId: 'demi-bille', number: 3): 'Exercice e3',
      ExerciseRef(blockId: 'demi-bille', number: 4): 'Exercice e4',
    });
  });

  test('finds the option of a known session only', () {
    expect(sheetOptionOf(sheets, SheetId('demi-bille-2'))?.part, 2);
    expect(sheetOptionOf(sheets, SheetId('inconnue-9')), isNull);
    expect(sheetOptionOf(sheets, null), isNull);
  });
}
