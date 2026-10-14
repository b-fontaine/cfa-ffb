import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/progress_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the progress bar track is not red
///
/// Affiche une jauge sous le thème réel de l'application et vérifie que sa
/// piste est neutre ou bleu-tapis, jamais rouge.
Future<void> theProgressBarTrackIsNotRed(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.pumpWidget(
    MaterialApp(
      theme: Theme.of(context),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: ProgressMeter(value: 3, maximum: 5, label: '3/5'),
      ),
    ),
  );
  final bar = tester.widget<LinearProgressIndicator>(
    find.byType(LinearProgressIndicator),
  );
  final track = bar.backgroundColor!;
  expect(track.b, greaterThanOrEqualTo(track.r));
}
