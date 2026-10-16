import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/review_session/domain/get_session_review.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_next_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: je demande la séance suivante du bilan
Future<void> jeDemandeLaSeanceSuivanteDuBilan(WidgetTester tester) async {
  final world = TrackingWorld.current;
  world.reviewResult = await getIt<GetSessionReview>()(world.currentSession!);
  final review = TrackingWorld.valueOf(world.reviewResult);
  world.nextSheet = TrackingWorld.valueOf(
    await getIt<SuggestNextSheet>()(
      groupId: review.record.groupId,
      present: review.record.present,
    ),
  );
}
