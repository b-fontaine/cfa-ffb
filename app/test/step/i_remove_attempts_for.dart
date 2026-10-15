import 'package:flutter_test/flutter_test.dart';

import '../support/attempts_counter.dart';

/// Usage: I remove {3} attempts for {'Léa'}
Future<void> iRemoveAttemptsFor(WidgetTester tester, num count, String name) =>
    tapAttemptsCounter(tester, name, 'Fewer attempts for $name', count);
