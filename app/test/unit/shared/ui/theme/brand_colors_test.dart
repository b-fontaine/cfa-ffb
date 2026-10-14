import 'package:billard_cfa/shared/ui/theme/brand_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark carry the FFB red accent (darkened for text)', () {
    expect(BrandColors.light.accent, const Color(0xFFB80D1A));
    expect(BrandColors.dark.accent, const Color(0xFFFFB3AD));
  });

  test('copyWith replaces only the given fields', () {
    final changed = BrandColors.light.copyWith(accent: const Color(0xFF000000));

    expect(changed.accent, const Color(0xFF000000));
    expect(changed.onAccent, BrandColors.light.onAccent);
    expect(changed.accentContainer, BrandColors.light.accentContainer);
    expect(changed.onAccentContainer, BrandColors.light.onAccentContainer);
    expect(BrandColors.light.copyWith(), BrandColors.light);
  });

  test('lerp interpolates every color and ignores a foreign extension', () {
    final mid = BrandColors.light.lerp(BrandColors.dark, 0.5);

    expect(
      mid.accent,
      Color.lerp(BrandColors.light.accent, BrandColors.dark.accent, 0.5),
    );
    expect(BrandColors.light.lerp(BrandColors.dark, 0), BrandColors.light);
    expect(BrandColors.light.lerp(BrandColors.dark, 1), BrandColors.dark);
    expect(BrandColors.light.lerp(null, 0.5), BrandColors.light);
  });

  test('equality and hashCode follow the four colors', () {
    expect(BrandColors.light, isNot(BrandColors.dark));
    expect(BrandColors.light.hashCode, BrandColors.light.copyWith().hashCode);
    expect(
      BrandColors.light,
      isNot(BrandColors.light.copyWith(onAccentContainer: Colors.black)),
    );
  });
}
