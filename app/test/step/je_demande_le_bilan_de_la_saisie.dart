import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/review_session/domain/get_session_review.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je demande le bilan de la saisie {'inconnue'}
Future<void> jeDemandeLeBilanDeLaSaisie(
  WidgetTester tester,
  String sessionId,
) async {
  TrackingWorld.current.reviewResult = await getIt<GetSessionReview>()(
    SessionId(sessionId),
  );
}
