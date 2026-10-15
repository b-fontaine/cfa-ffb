import 'package:flutter_test/flutter_test.dart';

import '../support/attempts_counter.dart';

/// Usage: I add {3} attempts for {'Léa'}
Future<void> iAddAttemptsFor(WidgetTester tester, num count, String name) =>
    tapAttemptsCounter(tester, name, 'More attempts for $name', count);
