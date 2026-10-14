import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the club keeps {1} acquired blocks in total
Future<void> theClubKeepsAcquiredBlocksInTotal(
  WidgetTester tester,
  num count,
) async {
  expect(await getIt<AcquisitionRepository>().all(), hasLength(count.toInt()));
}
