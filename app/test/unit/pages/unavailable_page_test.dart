import 'package:billard_cfa/pages/unavailable/presentation/unavailable_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/ui/pump_ui.dart';

void main() {
  testWidgets('offers a retry, and no sign-out without an account', (
    tester,
  ) async {
    var retried = 0;
    await pumpUi(tester, UnavailablePage(onRetry: () => retried++));

    await tester.tap(find.text('Retry'));

    expect(retried, 1);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('a signed-in account can sign out', (tester) async {
    var signedOut = 0;
    await pumpUi(
      tester,
      UnavailablePage(onRetry: () {}, onSignOut: () => signedOut++),
    );

    await tester.tap(find.text('Sign out'));

    expect(signedOut, 1);
  });
}
