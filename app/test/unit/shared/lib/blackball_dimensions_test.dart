import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:flutter_test/flutter_test.dart';

// Valeurs attendues calculées à la main (plan tailles-et-illustrations § 5.1) :
// 1 case = 925 / 4 = 231,25 mm ; r_o = 25,4 mm ; r_c = 24,0 mm.
void main() {
  group('BlackballDimensions (cotes [FFB] en mm)', () {
    test('a cell is a quarter of the playing width', () {
      expect(BlackballDimensions.cellMm, 231.25);
      expect(BlackballDimensions.columns, 8);
      expect(BlackballDimensions.rows, 4);
    });

    test('the playing surface is 2:1, 8 x 4 cells', () {
      expect(
        BlackballDimensions.playAreaLengthMm /
            BlackballDimensions.playAreaWidthMm,
        2,
      );
      expect(
        BlackballDimensions.playAreaLengthMm / BlackballDimensions.cellMm,
        BlackballDimensions.columns,
      );
    });

    test('an object ball has a radius of 25.4 mm = 0.109838 cell', () {
      expect(BlackballDimensions.objectBallDiameterMm, 50.8);
      expect(BlackballDimensions.objectBallRadius, closeTo(0.109838, 1e-6));
    });

    test('the cue ball has a radius of 24.0 mm = 0.103784 cell', () {
      expect(BlackballDimensions.cueBallDiameterMm, 48.0);
      expect(BlackballDimensions.cueBallRadius, closeTo(0.103784, 1e-6));
    });

    test('the cue ball is smaller than an object ball', () {
      expect(
        BlackballDimensions.cueBallRadius,
        lessThan(BlackballDimensions.objectBallRadius),
      );
    });

    test('the ratio cue / object is 24.0 / 25.4 = 0.944882', () {
      expect(
        BlackballDimensions.cueBallRadius /
            BlackballDimensions.objectBallRadius,
        closeTo(0.944882, 1e-6),
      );
    });

    test('the contact distance is the sum of the radii, 0.213622 cell', () {
      expect(BlackballDimensions.ghostDistance, closeTo(0.213622, 1e-6));
      expect(
        BlackballDimensions.ghostDistance,
        lessThan(2 * BlackballDimensions.objectBallRadius),
      );
    });

    test('a pocket opens 76.2 mm = 0.329514 cell = 1.5 object balls', () {
      expect(BlackballDimensions.pocketOpening, closeTo(0.329514, 1e-6));
      expect(
        BlackballDimensions.pocketOpeningMm /
            BlackballDimensions.objectBallDiameterMm,
        closeTo(1.5, 1e-12),
      );
    });

    test('the head string is 1/5 of the length, at 1.6 cell', () {
      expect(BlackballDimensions.headString, closeTo(1.6, 1e-12));
    });

    test(
      'the tip is 8.5 / 48 of the cue ball diameter, between 8 and 9 mm',
      () {
        expect(BlackballDimensions.tipDiameterMm, 8.5);
        expect(BlackballDimensions.tipRadiusOnCueBall, closeTo(0.177083, 1e-6));
        expect(
          8 / BlackballDimensions.cueBallDiameterMm,
          closeTo(0.166667, 1e-6),
        );
        expect(9 / BlackballDimensions.cueBallDiameterMm, 0.1875);
      },
    );

    test('a cue is 1450 mm = 6.27 cells long with a 30 mm butt', () {
      expect(BlackballDimensions.cueLength, closeTo(6.2703, 1e-4));
      expect(BlackballDimensions.cueButtThickness, closeTo(0.12973, 1e-5));
      // Le procédé (8,5 mm) est plus fin que le talon : 0,283.
      expect(BlackballDimensions.cueTipToButt, closeTo(0.28333, 1e-5));
      expect(
        BlackballDimensions.cueButtThickness,
        lessThan(2 * BlackballDimensions.cueBallRadius),
      );
    });

    test('centres differ in height by 1.4 mm = 0.006054 cell', () {
      expect(BlackballDimensions.centerHeightGapMm, closeTo(1.4, 1e-9));
      expect(BlackballDimensions.centerHeightGap, closeTo(0.006054, 1e-6));
    });

    test(
      'the contact is 0.68 mm above the cue ball equator (1.62 degrees)',
      () {
        expect(BlackballDimensions.contactTiltDegrees, closeTo(1.6244, 1e-3));
        expect(
          BlackballDimensions.contactHeightAboveCueEquatorMm,
          closeTo(0.6802, 1e-3),
        );
        expect(
          BlackballDimensions.contactHeightAboveCueEquatorMm,
          lessThan(0.03 * BlackballDimensions.cueBallDiameterMm / 2),
        );
        expect(
          BlackballDimensions.contactHeightAboveCueEquatorMm,
          greaterThan(0),
        );
      },
    );
  });

  group('BallSizes', () {
    test('standard sizes are the retained FFB values', () {
      const sizes = BallSizes.standard;

      expect(sizes.cueRadius, closeTo(0.103784, 1e-6));
      expect(sizes.objectRadius, closeTo(0.109838, 1e-6));
      expect(sizes.ghostDistance, closeTo(0.213622, 1e-6));
      expect(sizes.ratio, closeTo(0.944882, 1e-6));
    });

    test('the WEPF cue ball of 47.6 mm gives s = 0.212757 and 0.937008', () {
      const sizes = BallSizes(cueDiameterMm: 47.6);

      expect(sizes.ghostDistance, closeTo(0.212757, 1e-6));
      expect(sizes.ratio, closeTo(0.937008, 1e-6));
    });

    test('equal balls give back s = 2 r_o = 0.219676 (regression)', () {
      const sizes = BallSizes(cueDiameterMm: 50.8);

      expect(sizes.ghostDistance, closeTo(0.219676, 1e-6));
      expect(sizes.ratio, 1);
    });

    test('radiusOf picks the cue radius for the cue ball only', () {
      const sizes = BallSizes.standard;

      expect(sizes.radiusOf(isCueBall: true), sizes.cueRadius);
      expect(sizes.radiusOf(isCueBall: false), sizes.objectRadius);
    });
  });
}
