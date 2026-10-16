import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';

/// Usage: la clôture est refusée avec le motif {'seasonAlreadyClosed'}
Future<void> laClotureEstRefuseeAvecLeMotif(
  WidgetTester tester,
  String code,
) async {
  final result = ClosureOps.lastClose;
  expect(result, isA<Err<ClosureResult>>(), reason: '$result');
  final failure = (result! as Err<ClosureResult>).failure;
  expect((failure as InvariantViolation).code.name, code);
}
