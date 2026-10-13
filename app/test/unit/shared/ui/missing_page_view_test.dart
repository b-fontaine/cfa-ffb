import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('says the page is missing and leads back home', (tester) async {
    var home = 0;
    await pumpUi(tester, MissingPageView(onHome: () => home++));

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Back to home'));

    expect(home, 1);
  });

  testWidgets('keeps the home button at least 48 dp tall', (tester) async {
    await pumpUi(tester, MissingPageView(onHome: () {}));

    final size = tester.getSize(find.byType(FilledButton));

    expect(size.height, greaterThanOrEqualTo(48));
  });
}
