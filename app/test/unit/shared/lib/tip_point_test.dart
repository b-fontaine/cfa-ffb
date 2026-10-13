import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('has the nine tip points of the sheet format', () {
    expect(TipPoint.values.map((p) => p.name), [
      'center',
      'top',
      'bottom',
      'left',
      'right',
      'topLeft',
      'topRight',
      'bottomLeft',
      'bottomRight',
    ]);
  });

  test('TipPoint is re-exported unchanged by shared/ui', () {
    expect(identical(ui.TipPoint.top, TipPoint.top), isTrue);
  });

  test('keeps the aim offset of the contact fractions', () {
    expect(ContactFraction.full.aimOffset(), 0);
    expect(ContactFraction.half.aimOffset(), closeTo(0.109838, 1e-6));
  });
}
