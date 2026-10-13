import 'package:billard_cfa/shared/ui/french_content_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('announces French content under the English interface', (
    tester,
  ) async {
    await pumpUi(tester, const FrenchContentNotice());

    expect(
      find.text(
        'The session content is written in French; only the interface is '
        'translated.',
      ),
      findsOneWidget,
    );
    expect(find.text('Warning'), findsOneWidget);
  });

  testWidgets('shows nothing under the French interface', (tester) async {
    await pumpUi(
      tester,
      const FrenchContentNotice(),
      locale: const Locale('fr'),
    );

    expect(find.byType(Text), findsNothing);
  });
}
