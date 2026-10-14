import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/timer_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: a timer chip with {120} seconds remaining
///
/// Affiche un minuteur sous le thème réel de l'application ; un temps
/// négatif représente un dépassement.
Future<void> aTimerChipWithSecondsRemaining(
  WidgetTester tester,
  num seconds,
) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.pumpWidget(
    MaterialApp(
      theme: Theme.of(context),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TimerChip(
          remaining: Duration(seconds: seconds.toInt()),
          running: true,
          onToggle: () {},
        ),
      ),
    ),
  );
}
