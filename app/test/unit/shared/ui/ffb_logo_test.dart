import 'package:billard_cfa/shared/ui/ffb_logo.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

final ThemeData _withLogo = AppTheme.light(showFfbLogo: true);

void main() {
  testWidgets('shows the logo with its accessible label by default', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const FfbLogo(height: 80), theme: _withLogo);

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.bySemanticsLabel('French Billiards Federation logo'),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(Image)).height, 80);
    expect(tester.getSize(find.byType(Image)).width, closeTo(128, 0.01));
    handle.dispose();
  });

  testWidgets('is French when the locale is French', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      const FfbLogo(),
      locale: const Locale('fr'),
      theme: _withLogo,
    );

    expect(
      find.bySemanticsLabel('Logo de la Fédération française de billard'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('can be decorative (hidden from assistive technologies)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const FfbLogo(decorative: true), theme: _withLogo);

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.bySemanticsLabel('French Billiards Federation logo'),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('stays empty when the theme carries no brand assets', (
    tester,
  ) async {
    await pumpUi(tester, const FfbLogo(), theme: ThemeData());

    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byType(FfbLogo)), Size.zero);
  });

  testWidgets('stays empty with the default theme (logo switched off)', (
    tester,
  ) async {
    await pumpUi(tester, const FfbLogo());

    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byType(FfbLogo)), Size.zero);
  });

  testWidgets('shows nothing when the asset cannot be found', (tester) async {
    final theme = ThemeData(
      extensions: const [BrandAssets(logo: AssetImage('assets/missing.png'))],
    );
    await pumpUi(tester, const FfbLogo(), theme: theme);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}
