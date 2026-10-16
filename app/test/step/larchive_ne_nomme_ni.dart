import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'archive ne nomme ni {'Léa, Théo, Hugo'}
Future<void> larchiveNeNommeNi(WidgetTester tester, String names) async {
  final archives = await getIt<SeasonArchiveRepository>().all();
  expect(archives, isNotEmpty);
  final text = archives.join();
  for (final name in TrackingWorld.names(names)) {
    expect(text, isNot(contains(name)));
    expect(text, isNot(contains(TrackingWorld.studentId(name).value)));
  }
}
