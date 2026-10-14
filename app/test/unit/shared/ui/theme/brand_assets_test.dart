import 'dart:io';
import 'dart:typed_data';

import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    test('the ${entry.key} theme carries no logo by default', () {
      final assets = entry.value().extension<BrandAssets>()!;

      expect(assets.logo, isNull);
    });

    test('the ${entry.key} theme carries the FFB logo once enabled', () {
      final assets = entry.value(showFfbLogo: true).extension<BrandAssets>()!;

      expect(assets.logo!.assetName, 'assets/images/ffb-logo.png');
      expect(assets.logo!.package, isNull);
    });

    test('the ${entry.key} theme resolves the logo from a host package', () {
      final assets = entry
          .value(assetPackage: 'billard_cfa', showFfbLogo: true)
          .extension<BrandAssets>()!;

      expect(assets.logo!.package, 'billard_cfa');
      expect(
        assets.logo!.keyName,
        'packages/billard_cfa/assets/images/ffb-logo.png',
      );
    });
  }

  test('copyWith replaces the logo and lerp keeps the nearest one', () {
    const base = BrandAssets(logo: AssetImage('a.png'));
    const other = BrandAssets(logo: AssetImage('b.png'));

    expect(
      base.copyWith(logo: const AssetImage('c.png')).logo!.assetName,
      'c.png',
    );
    expect(base.copyWith(), base);
    expect(base.lerp(other, 0.2), base);
    expect(base.lerp(other, 0.8), other);
    expect(base.lerp(null, 0.8), base);
  });

  test('the aspect ratio matches the bundled PNG', () {
    final header = File(BrandAssets.logoAsset)
        .readAsBytesSync()
        .sublist(16, 24);
    final data = ByteData.sublistView(Uint8List.fromList(header));

    expect(
      data.getUint32(0) / data.getUint32(4),
      closeTo(BrandAssets.logoAspectRatio, 0.001),
    );
  });

  test('the logo file is a PNG (signature checked before reading sizes)', () {
    final bytes = File(BrandAssets.logoAsset).readAsBytesSync();

    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
  });

  test('lerp switches at the midpoint and equality follows the logo', () {
    const base = BrandAssets(logo: AssetImage('a.png'));
    const other = BrandAssets(logo: AssetImage('b.png'));

    expect(base.lerp(other, 0.5), other);
    expect(base, isNot(other));
    expect(
      base.hashCode,
      const BrandAssets(logo: AssetImage('a.png')).hashCode,
    );
  });
}
