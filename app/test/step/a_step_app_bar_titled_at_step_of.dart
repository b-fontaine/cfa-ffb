import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/step_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: a step app bar titled {'Training'} at step {6} of {9}
///
/// Affiche l'en-tête d'étape sous le thème réel, avec deux actions injectées
/// (« Summary » et « Finish session »).
Future<void> aStepAppBarTitledAtStepOf(
  WidgetTester tester,
  String title,
  num position,
  num total,
) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.pumpWidget(
    MaterialApp(
      theme: Theme.of(context),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: StepAppBar(
          title: title,
          position: position.toInt(),
          total: total.toInt(),
          onBack: () {},
          actions: [
            StepAppBarAction(label: 'Summary', onSelected: () {}),
            StepAppBarAction(label: 'Finish session', onSelected: () {}),
          ],
        ),
      ),
    ),
  );
}
