import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/ffb_logo.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows the title and the subtitle', (tester) async {
    await pumpUi(
      tester,
      const PageHeader(title: 'Planning', subtitle: 'Season 2026'),
    );

    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Season 2026'), findsOneWidget);
  });

  testWidgets('omits the subtitle when absent', (tester) async {
    await pumpUi(tester, const PageHeader(title: 'Planning'));

    expect(find.text('Planning'), findsOneWidget);
    expect(find.byType(PageHeader), findsOneWidget);
    expect(find.text('Season 2026'), findsNothing);
  });

  testWidgets('marks the title as a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const PageHeader(title: 'Planning'));

    expect(
      tester.getSemantics(find.text('Planning')),
      isSemantics(label: 'Planning', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('shows the decorative FFB logo by default', (tester) async {
    await pumpUi(tester, const PageHeader(title: 'Planning'));

    expect(find.byType(FfbLogo), findsOneWidget);
    expect(tester.widget<FfbLogo>(find.byType(FfbLogo)).decorative, isTrue);
  });

  testWidgets('hides the logo on request', (tester) async {
    await pumpUi(tester, const PageHeader(title: 'Planning', showLogo: false));

    expect(find.byType(FfbLogo), findsNothing);
  });

  testWidgets('drops the logo rather than wrapping a long title', (
    tester,
  ) async {
    await pumpUi(tester, PageHeader(title: 'A very long page title ' * 8));

    expect(find.byType(FfbLogo), findsNothing);
  });

  testWidgets('reserves no room for the logo without brand assets', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const PageHeader(title: 'Planning'),
      theme: ThemeData(),
    );

    expect(find.byType(FfbLogo), findsNothing);
  });

  Widget inWidth(double width, Widget child) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  );

  testWidgets('keeps the logo when the title fits next to it', (tester) async {
    await pumpUi(tester, inWidth(600, const PageHeader(title: 'Planning')));

    expect(find.byType(FfbLogo), findsOneWidget);
    expect(tester.getSize(find.byType(FfbLogo)).width, closeTo(32 * 1.6, 0.01));
    expect(find.text('Planning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drops the logo and keeps the whole title when narrow', (
    tester,
  ) async {
    await pumpUi(tester, inWidth(120, const PageHeader(title: 'Planning')));

    expect(find.byType(FfbLogo), findsNothing);
    expect(find.text('Planning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drops the logo when a larger text scale needs the room', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: inWidth(260, const PageHeader(title: 'Planning'))),
      ),
    );

    expect(find.byType(FfbLogo), findsNothing);
  });

  testWidgets('does not announce the logo and keeps the heading', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, inWidth(600, const PageHeader(title: 'Planning')));

    expect(find.byType(FfbLogo), findsOneWidget);
    expect(
      find.bySemanticsLabel('French Billiards Federation logo'),
      findsNothing,
    );
    expect(
      tester.getSemantics(find.text('Planning')),
      isSemantics(label: 'Planning', isHeader: true),
    );
    handle.dispose();
  });
}
