import 'package:billard_cfa/shared/ui/ffb_logo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the FFB logo
Future<void> iSeeTheFfbLogo(WidgetTester tester) async {
  expect(find.byType(FfbLogo), findsOneWidget);
}
