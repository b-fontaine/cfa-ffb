import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('loading view shows a progress indicator', (tester) async {
    await pumpUi(tester, const LoadingView());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loading view is announced in the device language', (
    tester,
  ) async {
    await pumpUi(tester, const LoadingView(), locale: const Locale('fr'));

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.semanticsLabel, 'Chargement…');
  });

  testWidgets('error view shows the message and retries', (tester) async {
    var retries = 0;
    await pumpUi(
      tester,
      ErrorView(message: 'Not found.', onRetry: () => retries++),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Not found.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('error view without retry has no button', (tester) async {
    await pumpUi(tester, const ErrorView(message: 'Nope'));

    expect(find.byType(FilledButton), findsNothing);
  });
}
