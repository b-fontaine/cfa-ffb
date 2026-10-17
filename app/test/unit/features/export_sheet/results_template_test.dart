import 'package:billard_cfa/features/export_sheet/domain/results_template.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Constantes mesurées sur `docs/sources/Fiches résultats CFA blackball.pdf`
/// (`pdftotext -bbox` pour les textes, `pdftocairo -svg` pour les traits) ;
/// les valeurs attendues sont recopiées de ces mesures, pas de la
/// constante testée.
void main() {
  group('ResultsTemplate', () {
    test('page is A4 portrait in points', () {
      expect(ResultsTemplate.pageWidth, closeTo(595, 0.1));
      expect(ResultsTemplate.pageHeight, closeTo(842, 0.1));
    });

    test('four blocks per page, two by two', () {
      expect(ResultsTemplate.blocksPerRow, 2);
      expect(ResultsTemplate.blocksPerPage, 4);
    });

    test('block pitch matches the second block of the federal sheet', () {
      // « Nom : » 2e bloc x = 282,65 pour 14,4 : 268,25 ; traits : 268,8.
      expect(ResultsTemplate.blockPitchX, closeTo(268.5, 0.4));
      // « Nom : » 3e bloc y = 444,43 pour 62,64 : 381,79 ; traits : 381,2.
      expect(ResultsTemplate.blockPitchY, closeTo(381.5, 0.4));
    });

    test('five attempt columns of 32.5 points start at x = 85.8', () {
      expect(ResultsTemplate.defaultColumns, 5);
      expect(ResultsTemplate.gridLeft, closeTo(85.8, 0.1));
      expect(
        ResultsTemplate.gridWidth / ResultsTemplate.defaultColumns,
        closeTo(32.5, 0.1),
      );
    });

    test('the grid spans 17 bands from y = 128.4 to 370.9', () {
      expect(ResultsTemplate.bands, 17);
      expect(ResultsTemplate.gridTop, closeTo(128.4, 0.1));
      expect(ResultsTemplate.gridBottom, closeTo(370.9, 0.1));
      expect(ResultsTemplate.bandHeight, closeTo(14.26, 0.05));
    });

    test('the scale runs from 0 to the maximum of a success rate', () {
      expect(ResultsTemplate.scaleMax, SuccessRate.maxAttempts);
      expect(ResultsTemplate.scaleMax, 16);
      expect(ResultsTemplate.bands, ResultsTemplate.scaleMax + 1);
    });

    test(
      'the header box spans x = 11.2 to 248.4 between y = 87.8 and 115.7',
      () {
        expect(ResultsTemplate.boxLeft, closeTo(11.2, 0.1));
        expect(ResultsTemplate.boxRight, closeTo(248.4, 0.1));
        expect(ResultsTemplate.headerTop, closeTo(60.0, 0.1));
        expect(ResultsTemplate.headerMiddle, closeTo(87.8, 0.1));
        expect(ResultsTemplate.headerBottom, closeTo(115.7, 0.1));
      },
    );

    test('the columns are clamped between 3 and 8', () {
      expect(ResultsTemplate.clampColumns(2), 3);
      expect(ResultsTemplate.clampColumns(5), 5);
      expect(ResultsTemplate.clampColumns(6), 6);
      expect(ResultsTemplate.clampColumns(12), 8);
    });

    test('the grid keeps its width whatever the number of columns', () {
      expect(ResultsTemplate.columnWidth(5), closeTo(32.5, 0.01));
      expect(ResultsTemplate.columnWidth(6) * 6, closeTo(162.5, 0.01));
    });
  });
}
