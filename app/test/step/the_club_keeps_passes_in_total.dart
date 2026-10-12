import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the club keeps {2} passes in total
Future<void> theClubKeepsPassesInTotal(WidgetTester tester, num count) async {
  expect(await getIt<AttemptRepository>().all(), hasLength(count.toInt()));
}
