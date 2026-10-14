import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: a phase timeline of {120} minutes with the phase {2} current
///
/// Affiche la frise des cinq phases d'une séance de 90 ou 120 minutes sous
/// le thème réel ; taper une phase la rend courante. Les phases sont
/// numérotées à partir de 1.
Future<void> aPhaseTimelineOfMinutesWithThePhaseCurrent(
  WidgetTester tester,
  num minutes,
  num current,
) async {
  final context = tester.element(find.byType(Scaffold).first);
  final weights = minutes.toInt() == 90
      ? const [5, 10, 35, 30, 10]
      : const [10, 15, 45, 35, 15];
  const labels = ['Warm-up', 'Notion', 'Training', 'Game', 'Review'];
  var index = current.toInt() - 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: Theme.of(context),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => PhaseTimeline(
            phases: [
              for (var i = 0; i < labels.length; i++)
                PhaseTimelineEntry(label: labels[i], minutes: weights[i]),
            ],
            currentIndex: index,
            onSelected: (selected) => setState(() => index = selected),
          ),
        ),
      ),
    ),
  );
}
