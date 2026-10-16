import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';
import '../support/tracking_world.dart';

/// Usage: la proposition pour {'Léa'} est de {'keep'} pour le motif
///   {'carriedOver'}
Future<void> laPropositionPourEstDePourLeMotif(
  WidgetTester tester,
  String student,
  String choice,
  String reason,
) async {
  final proposal = ClosureOps.currentPlan.proposals.firstWhere(
    (p) => p.studentId == TrackingWorld.studentId(student),
  );
  expect(proposal.choice.name, choice);
  expect(proposal.reason.name, reason);
}
