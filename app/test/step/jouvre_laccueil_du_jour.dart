import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/plan_session/domain/get_upcoming_sessions.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/features/track_progress/domain/get_week_summary.dart';
import 'package:billard_cfa/features/track_progress/domain/list_watched_students.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'ouvre l'accueil du jour
Future<void> jouvreLaccueilDuJour(WidgetTester tester) async {
  TrackingWorld.current
    ..upcoming = TrackingWorld.valueOf(await getIt<GetUpcomingSessions>()())
    ..watchList = TrackingWorld.valueOf(await getIt<ListWatchedStudents>()())
    ..week = TrackingWorld.valueOf(await getIt<GetWeekSummary>()())
    ..running = getIt<RunSheetSessions>().snapshot();
}
