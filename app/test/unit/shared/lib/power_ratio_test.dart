import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Produits calculés à la main (fiche n° 2 : les deux extrêmes viennent de la
  // source, la grille intermédiaire est [Prop]).
  const expected = <(AmplitudeLevel, SpeedLevel, double, PowerZone)>[
    (AmplitudeLevel.short, SpeedLevel.slow, 0.09, PowerZone.soft),
    (AmplitudeLevel.short, SpeedLevel.medium, 0.18, PowerZone.soft),
    (AmplitudeLevel.short, SpeedLevel.fast, 0.30, PowerZone.medium),
    (AmplitudeLevel.medium, SpeedLevel.slow, 0.18, PowerZone.soft),
    (AmplitudeLevel.medium, SpeedLevel.medium, 0.36, PowerZone.medium),
    (AmplitudeLevel.medium, SpeedLevel.fast, 0.60, PowerZone.strong),
    (AmplitudeLevel.long, SpeedLevel.slow, 0.30, PowerZone.medium),
    (AmplitudeLevel.long, SpeedLevel.medium, 0.60, PowerZone.strong),
    (AmplitudeLevel.long, SpeedLevel.fast, 1.00, PowerZone.strong),
  ];

  test('gives the zone of each of the nine combinations', () {
    for (final (amplitude, speed, product, zone) in expected) {
      expect(
        amplitude.value * speed.value,
        closeTo(product, 1e-9),
        reason: '$amplitude x $speed',
      );
      expect(powerZone(amplitude, speed), zone, reason: '$amplitude x $speed');
    }
  });

  test('keeps the two extremes of the source', () {
    expect(powerZone(AmplitudeLevel.short, SpeedLevel.slow), PowerZone.soft);
    expect(powerZone(AmplitudeLevel.long, SpeedLevel.fast), PowerZone.strong);
  });

  test('never decreases when the amplitude or the speed increases', () {
    for (final speed in SpeedLevel.values) {
      for (var i = 1; i < AmplitudeLevel.values.length; i++) {
        final lower = powerZone(AmplitudeLevel.values[i - 1], speed);
        final upper = powerZone(AmplitudeLevel.values[i], speed);

        expect(upper.index, greaterThanOrEqualTo(lower.index));
      }
    }
    for (final amplitude in AmplitudeLevel.values) {
      for (var i = 1; i < SpeedLevel.values.length; i++) {
        final lower = powerZone(amplitude, SpeedLevel.values[i - 1]);
        final upper = powerZone(amplitude, SpeedLevel.values[i]);

        expect(upper.index, greaterThanOrEqualTo(lower.index));
      }
    }
  });

  test('cuts the zones at 0.2 and 0.5', () {
    expect(powerZoneOfProduct(0.199), PowerZone.soft);
    expect(powerZoneOfProduct(0.2), PowerZone.medium);
    expect(powerZoneOfProduct(0.499), PowerZone.medium);
    expect(powerZoneOfProduct(0.5), PowerZone.strong);
  });

  test('a point knows its zone and is equal by value', () {
    const point = PowerPoint(
      amplitude: AmplitudeLevel.long,
      speed: SpeedLevel.fast,
      label: 'bille lointaine',
    );

    expect(point.zone, PowerZone.strong);
    expect(
      point,
      const PowerPoint(
        amplitude: AmplitudeLevel.long,
        speed: SpeedLevel.fast,
        label: 'bille lointaine',
      ),
    );
    expect(
      point ==
          const PowerPoint(
            amplitude: AmplitudeLevel.long,
            speed: SpeedLevel.fast,
          ),
      isFalse,
    );
  });

  test('equal points share a hash code and a readable description', () {
    const a = PowerPoint(
      amplitude: AmplitudeLevel.short,
      speed: SpeedLevel.slow,
      label: 'x',
    );
    const b = PowerPoint(
      amplitude: AmplitudeLevel.short,
      speed: SpeedLevel.slow,
      label: 'x',
    );

    expect(a.hashCode, b.hashCode);
    expect(
      a.toString(),
      'PowerPoint(AmplitudeLevel.short, SpeedLevel.slow, x)',
    );
  });
}
