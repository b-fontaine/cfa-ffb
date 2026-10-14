import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance planifiée {'Cours'} est prévue le {'2026-10-19'} pour le
/// groupe {'Jeunes'}
Future<void> laSeancePlanifieeEstPrevueLePourLeGroupe(
  WidgetTester tester,
  String title,
  String date,
  String group,
) async {
  final sessions = await getIt<SessionRepository>().getAll();
  final session = sessions.singleWhere((s) => s.title == title);
  expect(session.date, TrackingWorld.date(date));
  expect(session.groupId, TrackingWorld.groupId(group));
}
