import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> leClubCompteBlocsAcquis(WidgetTester tester, num count) async {
  expect(await getIt<AcquisitionRepository>().all(), hasLength(count.toInt()));
}
