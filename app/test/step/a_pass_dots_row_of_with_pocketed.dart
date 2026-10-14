import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/pass_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: a pass dots row of {5} with {2} pocketed
///
/// Affiche une rangée de pastilles modifiable sous le thème réel de
/// l'application ; les `n` premières sont empochées.
Future<void> aPassDotsRowOfWithPocketed(
  WidgetTester tester,
  num total,
  num pocketed,
) async {
  final context = tester.element(find.byType(Scaffold).first);
  var value = [for (var i = 0; i < total; i++) i < pocketed];
  await tester.pumpWidget(
    MaterialApp(
      theme: Theme.of(context),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => PassDots(
            value: value,
            total: total.toInt(),
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    ),
  );
}
