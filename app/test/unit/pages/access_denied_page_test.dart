import 'package:billard_cfa/pages/unavailable/presentation/access_denied_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/ui/pump_ui.dart';

void main() {
  testWidgets('says access is refused and offers no retry', (tester) async {
    await pumpUi(tester, AccessDeniedPage(onSignOut: () {}));

    expect(find.text('Access to your clubs refused'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('signing out is always possible', (tester) async {
    var signedOut = 0;
    await pumpUi(tester, AccessDeniedPage(onSignOut: () => signedOut++));

    await tester.tap(find.text('Sign out'));

    expect(signedOut, 1);
  });
}
