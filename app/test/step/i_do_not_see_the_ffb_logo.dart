import 'package:billard_cfa/shared/ui/ffb_logo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I do not see the FFB logo
Future<void> iDoNotSeeTheFfbLogo(WidgetTester tester) async {
  expect(find.byType(FfbLogo), findsNothing);
}
