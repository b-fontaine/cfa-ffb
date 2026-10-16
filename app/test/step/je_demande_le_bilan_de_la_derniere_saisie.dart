import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/review_session/domain/get_session_review.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je demande le bilan de la dernière saisie
Future<void> jeDemandeLeBilanDeLaDerniereSaisie(WidgetTester tester) async {
  final world = TrackingWorld.current;
  world.reviewResult = await getIt<GetSessionReview>()(world.currentSession!);
}
