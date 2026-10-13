import 'dart:async';

import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_ticker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('emits one event per second', (tester) async {
    var ticks = 0;
    final sub = PeriodicRunTicker().ticks().listen((_) => ticks++);

    await tester.pump(const Duration(seconds: 3));
    expect(ticks, 3);
    unawaited(sub.cancel());
    await tester.pump(const Duration(seconds: 3));

    expect(ticks, 3);
  });
}
